//
//  QuoteService.swift
//  Combine-MVVM-Transform
//
//  Created by 김민준 on 12/31/24.
//

import Foundation
import Combine

/// DIP를 위한 프로토콜
protocol QuoteServiceType {
    
    /// 랜덤 인용구 반환: Publisher 타입으로 반환
    func getRandomQuote() -> AnyPublisher<Quote, Error>
}

final class QuoteService: QuoteServiceType {
    
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
