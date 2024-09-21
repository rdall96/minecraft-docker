//
//  URLSession.swift
//
//
//  Created by Ricky Dall'Armellina on 8/11/23.
//

import Foundation

// On linux the URLSession symbol is not in Foundation but in FoundationNetworking.
// Import that here if we can, and add a global typealias so we don't need to import it everwhere else
#if canImport(FoundationNetworking)
import FoundationNetworking
typealias URLSession = FoundationNetworking.URLSession
#endif

// URLSession extension because `.data(from:)` is not available in linux.
extension URLSession {
    
    /// A linux friendly method to fetch data with a URLSession asynchronously
    func data(for url: URL) async throws -> (Data, URLResponse) {
        try await withUnsafeThrowingContinuation { continuation in
            let sem = DispatchSemaphore(value: 0)
            let task = dataTask(with: url, completionHandler: { data, response, error in
                if let error {
                    continuation.resume(throwing: error)
                }
                if let data, let response {
                    continuation.resume(returning: (data, response))
                }
                else {
                    // this should never occur,either we have data, or we have an error
                    continuation.resume(throwing: URLError(.unknown))
                }
                sem.signal()
            })
            task.resume()
            // we need to wait here to hold a strong reference to the task so it doesn't get destroyed before it completes
            sem.wait()
        }
    }
    
    /// A linux friendly method to downlaod files with a URLSession asynchronously
    func download(from url: URL) async throws -> (URL, URLResponse) {
        try await withUnsafeThrowingContinuation { continuation in
            let sem = DispatchSemaphore(value: 0)
            let task = downloadTask(with: url, completionHandler: { path, response, error in
                if let error {
                    continuation.resume(throwing: error)
                }
                if let path, let response {
                    continuation.resume(returning: (path, response))
                }
                else {
                    // this should never occur,either we have data, or we have an error
                    continuation.resume(throwing: URLError(.unknown))
                }
                sem.signal()
            })
            task.resume()
            // we need to wait here to hold a strong reference to the task so it doesn't get destroyed before it completes
            sem.wait()
        }
    }
    
}
