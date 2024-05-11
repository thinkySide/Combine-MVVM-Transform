//
//  ViewController.swift
//  Combine-MVVM-Transform
//
//  Created by 김민준 on 5/11/24.
//

import UIKit
import Combine

/// Transform Input & Output 패턴을 위한 ViewModelType 프로토콜
protocol ViewModelType {
    associatedtype Input
    associatedtype Output
    func transform(input: AnyPublisher<Input, Never>) -> AnyPublisher<Output, Never>
}

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

/// DIP를 위한 프로토콜
protocol QuoteServiceType {
    
    /// 랜덤 인용구 반환: Publisher 타입으로 반환
    func getRandomQuote() -> AnyPublisher<Quote, Error>
}

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

/// API에서 가져올 데이터
struct Quote: Decodable {
    let content: String
    let author: String
}
