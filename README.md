# Combine-MVVM-Transform(Input&Output) 연습장

> 본 코드는 [Youtube 강의](https://www.youtube.com/watch?v=KK6ryBmTKHg)를 보고 따라 작성해 본 것입니다!

## 왜 이 패턴을 공부하게 되었는가요?
이전에 프로젝트를 진행하면서 비동기 이벤트 처리에 대한 필요성을 절실히 느꼈던 적이 있습니다.
수많은 `Delegate`, `Notification`, `콜백 함수`들로 인해 어떤 코드를 고쳐야 이벤트를 조작할 수 있는지 감을 잡기 어려운 수준까지,, 왔었으니까요.
이런 부분들을 해결해 줄 수 있는 것이 대표적으로 `RxSwift`와 `Combine`이 있다는 것을 찾아보며 알았습니다. 처음에는 `RxSwift를 이용해` 보려 했었습니다.
하지만 제 성격 상 외부 의존성(써드 파티)을 추가한다는 것은 맞지 않다고 생각했고, Apple이 잘 만들어놓은게 있는데 까짓거 이걸로 도전해보자! 라는 마음으로 공부하게 되었습니다.
`Combine`의 기본적인 개념들을 학습하고 실제 프로젝트에는 어떻게 적용되는지 찾아보다 좋은 영상을 찾게 되어 여기까지 흘러오게 되었네요.

## 코드 미리보기

### NetworkingService(protocol)
~~~swift
/// DIP를 위한 프로토콜
protocol QuoteServiceType {
    
    /// 랜덤 인용구 반환: Publisher 타입으로 반환
    func getRandomQuote() -> AnyPublisher<Quote, Error>
}
~~~

### NetworkingService(구현부)
~~~swift
class QuoteService: QuoteServiceType {
    
    /// 랜덤 인용구 반환: Publisher 타입으로 반환
    func getRandomQuote() -> AnyPublisher<Quote, Error> {
        
        // 1. URL 생성
        let url = URL(string: "https://api.quotable.io/random")!
        
        // 2. dataTaskPublisher로 Publisher 생성
        // catch: 에러처리 -> Fail 퍼블리셔 생성 후 erase
        // map: 우선 Data로 변환
        // decode: Quote 타입으로 만들기 위해 디코딩
        // 마지막 erase
        return URLSession.shared.dataTaskPublisher(for: url)
            .catch { Fail(error: $0).eraseToAnyPublisher() }
            .map { $0.data }
            .decode(type: Quote.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
}
~~~

### DTO
~~~swift
/// API에서 가져올 데이터
struct Quote: Decodable {
    let content: String
    let author: String
}
~~~

### ViewModelType(protocol)
~~~swift
/// Transform Input & Output 패턴을 위한 ViewModelType 프로토콜
protocol ViewModelType {
    associatedtype Input
    associatedtype Output
    func transform(input: AnyPublisher<Input, Never>) -> AnyPublisher<Output, Never>
}
~~~

### ViewModel(Output)
~~~swift
class QuoteViewModel: ViewModelType {
    
    /// ViewController가 ViewModel에게 Input 할 이벤트
    enum Input {
        case viewDidAppear // 화면이 떴을 때
        case refreshButtonDidTap // 리프레쉬 버튼을 탭했을 때
    }
    
    /// ViewModel이 ViewController에게 Output 할 이벤트
    enum Output {
        case fetchQuoteDidFail(error: Error) // 데이터 패치에 실패했을 때
        case fetchQuoteDidSucceed(quote: Quote) // 데이터 패치에 성공했을 때
        case toggleRefreshButton(isEnabled: Bool) // 리프레쉬 버튼을 활성화할지 여부
    }
    
    // DIP를 위한 프로토콜 타입 지정
    private let quoteServiceType: QuoteServiceType
    
    // 기본값이 없는 PassthroughSubject
    // subscribe 전에 방출된 값을 받을 수 없음
    // 말 그대로 데이터가 지나가는 것
    private let output: PassthroughSubject<Output, Never> = .init()
    
    private var cancellables = Set<AnyCancellable>()
    
    // DIP 생성자
    init(quoteServiceType: QuoteServiceType = QuoteService()) {
        self.quoteServiceType = quoteServiceType
    }
    
    /// Input을 Output으로 변환하는 메서드
    func transform(input: AnyPublisher<Input, Never>) -> AnyPublisher<Output, Never> {
        
        input.sink { [weak self] event in
            switch event {
            case .viewDidAppear:
                
                // 화면이 나타났다는 이벤트 발생 시 인용구 업데이트
                self?.handleGetRandomQuote()
                
            case .refreshButtonDidTap:
                
                // 화면이 나타났다는 이벤트 발생 시 인용구 업데이트
                self?.handleGetRandomQuote()
            }
        }.store(in: &cancellables)
        
        // 최종 output 반환
        return output.eraseToAnyPublisher()
    }
    
    /// 랜덤 인용구 네트워킹 코드를 여기서 조작하기 위해 메서드 따로 뺌
    private func handleGetRandomQuote() {
        
        // 우선 처음에 버튼 비활성화
        output.send(.toggleRefreshButton(isEnabled: false))
        
        quoteServiceType.getRandomQuote().sink { [weak self] completion in
            
            // completion 이벤트 발생 시 다시 버튼 활성화
            self?.output.send(.toggleRefreshButton(isEnabled: true))
            
            // completion이 Error로 값이 들어온다면 Output 실패 이벤트 발생
            if case .failure(let error) = completion {
                self?.output.send(.fetchQuoteDidFail(error: error))
            }
        } receiveValue: { [weak self] quote in
            
            // 성공했을 때 quote와 함께 이벤트 발생
            self?.output.send(.fetchQuoteDidSucceed(quote: quote))
        }.store(in: &cancellables)
    }
}
~~~

### ViewController(Input)
~~~swift
class QuoteViewController: UIViewController {
    
    @IBOutlet weak var quoteLabel: UILabel!
    @IBOutlet weak var refreshButton: UIButton!
    
    private let viewModel = QuoteViewModel()
    private let input: PassthroughSubject<QuoteViewModel.Input, Never> = .init()
    
    // 메모리 관리를 위한 Cancellable 보관
    // 구독이 일어난 후 해제를 해줘야하는데 요기에 보관해서 한번에 관리할 수 있는 것.
    private var cancellables = Set<AnyCancellable>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        bind()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // View가 나타났을 때 Input에 미리 정의해 뒀던 이벤트 전달
        input.send(.viewDidAppear)
    }
    
    @IBAction func refreshButtonTapped(_ sender: Any) {
        
        // RefreshButton이 탭되었을 때 Input에 미리 정의해 뒀던 이벤트 전달
        input.send(.refreshButtonDidTap)
    }
    
    /// ViewModel과 바인딩 메서드
    private func bind() {
        
        // ViewController의 Input을 ViewModel에 전달 후
        // Output으로 변환 해서 받기
        let output = viewModel.transform(input: input.eraseToAnyPublisher())
        
        output
            // sink 내부에서 일어나는 모든 일이 Main Thread를 보장함.
            // Scheduler
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
            switch event {
            case .fetchQuoteDidFail(let error):
                // 데이터 패치에 실패하면 Label에 에러 메시지를 업데이트 함.
                self?.quoteLabel.text = error.localizedDescription
            
            case .fetchQuoteDidSucceed(let quote):
                // 데이터 패치에 성공하면 Label을 즉시 업데이트 함.
                self?.quoteLabel.text = quote.content
                
                /* 예전 같았으면 이렇게 코드를 썼을 거임
                 DispatchQueue.main.async {
                    self?.quoteLabel.text = quote.content
                 }
                 */
                
            case .toggleRefreshButton(let isEnabled):
                // 리프레쉬 버튼 토글 로직 업데이트
                self?.refreshButton.isEnabled = isEnabled
            }
        }.store(in: &cancellables)
    }
}
~~~
