//
//  Combine_MVVM_TransformTests.swift
//  Combine-MVVM-TransformTests
//
//  Created by 김민준 on 5/11/24.
//

import XCTest
import Combine

// 참조를 얻기 위한 코드
@testable import Combine_MVVM_Transform

final class Combine_MVVM_TransformTests: XCTestCase {
    
    var sut: QuoteViewModel!
    var quoteService: MockQuoteServiceType!

    override func setUp() {
        quoteService = MockQuoteServiceType()
        sut = QuoteViewModel(quoteServiceType: quoteService)
    }

    override func tearDown() {
        
    }
}

/// 테스트를 위한 Mock 클래스
class MockQuoteServiceType: QuoteServiceType {
    
    var value: AnyPublisher<Quote, Error>?
    
    func getRandomQuote() -> AnyPublisher<Quote, Error> {
        return value ?? Empty().eraseToAnyPublisher()
    }
}
