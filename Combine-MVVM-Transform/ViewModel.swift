//
//  ViewModel.swift
//  Combine-MVVM-Transform
//
//  Created by 김민준 on 12/31/24.
//

import Foundation
import Combine

/// Transform Input & Output 패턴을 위한 ViewModelType 프로토콜
protocol ViewModelType {
    associatedtype Input
    associatedtype Output
    func transform(input: AnyPublisher<Input, Never>) -> AnyPublisher<Output, Never>
}

final class QuoteViewModel: ViewModelType {
    
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
