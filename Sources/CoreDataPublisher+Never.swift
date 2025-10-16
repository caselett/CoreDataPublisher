//
//  CoreDataPublisher+Never.swift
//  CoreDataPublisher
//
//  Created by caselet on 3/7/25.
//

import Combine

extension CoreDataPublisher {
    func replacingError(_ errorReplace: Output = []) -> AnyPublisher<Output, Never> {
        replaceError(with: errorReplace).eraseToAnyPublisher()
    }
}
