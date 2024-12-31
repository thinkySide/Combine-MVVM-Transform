//
//  ViewController.swift
//  Combine-MVVM-Transform
//
//  Created by 김민준 on 5/11/24.
//

import UIKit
import Combine

final class QuoteViewController: UIViewController {
    
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
