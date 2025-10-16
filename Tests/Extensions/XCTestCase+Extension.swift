//
//  XCTestCase+Extension.swift
//  CoreDataPublisher
//
//  Created by caselet on 2/26/25.
//

import Combine
import XCTest

extension XCTestCase {
    func awaitPublisher<T: Publisher>(
        _ publisher: T,
        timeout: TimeInterval = 1,
        expectationCheck: ((T.Output) -> Bool)? = nil,
        file: StaticString = #file,
        line: UInt = #line
    ) throws -> T.Output where T.Failure == Never {
        var output: T.Output?
        let expectation = XCTestExpectation(description: "Awaiting publisher")

        let cancellable = publisher
            .sink { value in
                if let expectationCheck,
                   !expectationCheck(value) {
                    print("Awaiting publisher expectation check - false")
                    return
                }

                output = value
                expectation.fulfill()
            }

        wait(for: [expectation], timeout: timeout)
        cancellable.cancel()

        let unwrappedResult = try XCTUnwrap(
            output,
            "Awaited publisher did not produce any output",
            file: file,
            line: line
        )

        return unwrappedResult
    }

    class TestPublisher<T: Publisher> where T.Failure == Never {

        // MARK: - Published

        @Published
        private var output: T.Output?

        // MARK: - Init

        init(_ publisher: T) {
            cancellable = publisher.sink { [weak self] in
                self?.output = $0
            }
        }

        // MARK: - Properties

        var publisher: AnyPublisher<T.Output, Never> {
            $output
                .compactMap { $0 }
                .eraseToAnyPublisher()
        }

        private var cancellable: AnyCancellable?
    }
}
