//
//  Quote.swift
//  Combine-MVVM-Transform
//
//  Created by 김민준 on 12/31/24.
//

import Foundation

/// API에서 가져올 데이터
struct Quote: Decodable {
    let content: String
    let author: String
}
