/**
 * Copyright IBM Corporation 2016
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 **/

// MARK: RouterMiddlewareGenerator

class RouterMiddlewareGenerator: RouterMiddleware {

    ///
    /// The closure invoked to handle requests
    ///
    let handleInner: (RouterRequest, RouterResponse, (CallbackOption...) -> Void) -> Void

    ///
    /// Initalizes a RouterMiddlewareGenerator
    ///
    /// - Parameter handler: the closure to be called to handle requests
    ///
    /// - Returns: a RouterMiddlewareGenerator instance
    ///
    init(handler: (request: RouterRequest, response: RouterResponse, next: (CallbackOption...) -> Void) -> Void) {
        handleInner = handler
    }

    ///
    /// Implementation of RouterMiddleware protocol
    ///
    /// - Parameter request: the router request
    /// - Parameter response: the router response
    /// - Parameter next: the closure to the next operation
    ///
    func handle(request: RouterRequest, response: RouterResponse, next: (CallbackOption...) -> Void) {
        handleInner(request, response, next)
    }
}
