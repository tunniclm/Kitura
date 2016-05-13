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


import KituraNet

import Foundation

// MARK: StaticFileServer

public class StaticFileServer: RouterMiddleware {

    //
    // If a file is not found, the given extensions will be added to the file name and searched for. The first that exists will be served. Example: ['html', 'htm'].
    //
    private var possibleExtensions: [String]?

    //
    // Serve "index.html" files in response to a request on a directory.  Defaults to true.
    //
    private var serveIndexForDir = true

    //
    // Uses the file system's last modified value.  Defaults to true.
    //
    private var addLastModifiedHeader = true

    //
    // Value of max-age in Cache-Control header.  Defaults to 0.
    //
    private var maxAgeCacheControlHeader = 0

    //
    // Redirect to trailing "/" when the pathname is a dir. Defaults to true.
    //
    private var redirect = true

    //
    // A setter for custom response headers.
    //
    private var customResponseHeadersSetter: ResponseHeadersSetter?

    //
    // Generate ETag. Defaults to true.
    //
    private var generateETag = true



    private var path: String

    public convenience init (options: [Options]) {
        self.init(path: "./public", options: options)
    }

    public convenience init () {
        self.init(path: "./public", options: nil)
    }

    ///
    /// Initializes a StaticFileServer instance
    ///
    public init (path: String, options: [Options]?) {
        if path.hasSuffix("/") {
            self.path = String(path.characters.dropLast())
        } else {
            self.path = path
        }
        // If we received a path with a tlde (~) in the front, expand it.
#if os(Linux)
        self.path = self.path.bridge().stringByExpandingTildeInPath
#else
        self.path = self.path.bridge().expandingTildeInPath
#endif
        if let options = options {
            for option in options {
                switch option {
                case .possibleExtensions(let value):
                    possibleExtensions = value
                case .serveIndexForDir(let value):
                    serveIndexForDir = value
                case .addLastModifiedHeader(let value):
                    addLastModifiedHeader = value
                case .maxAgeCacheControlHeader(let value):
                    maxAgeCacheControlHeader = value
                case .redirect(let value):
                    redirect = value
                case .customResponseHeadersSetter(let value):
                    customResponseHeadersSetter = value
                case .generateETag (let value):
                    generateETag = value
                }
            }
        }
    }

    ///
    /// Handle the request
    ///
    /// - Parameter request: the router request
    /// - Parameter response: the router response
    /// - Parameter next: the closure for the next execution block
    ///
    public func handle (request: RouterRequest, response: RouterResponse, r: RouterCallback) {
        guard request.serverRequest.method == "GET" || request.serverRequest.method == "HEAD" else {
            return r.next()
        }
        
        var filePath = path
        if let requestPath = request.parsedUrl.path {
            var matchedPath = request.matchedPath
            if matchedPath.hasSuffix("*") {
                matchedPath = String(matchedPath.characters.dropLast())
            }
            if !matchedPath.hasSuffix("/") {
                matchedPath += "/"
            }
            
            if requestPath.hasPrefix(matchedPath) {
                let url = String(requestPath.characters.dropFirst(matchedPath.characters.count))
                filePath += "/" + url
            }
            
            if filePath.hasSuffix("/") {
                if serveIndexForDir {
                    filePath += "index.html"
                } else {
                    r.next()
                    return
                }
            }
            
            let fileManager = NSFileManager()
            var isDirectory = ObjCBool(false)
            
            if fileManager.fileExists(atPath: filePath, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    if redirect {
                        do {
                            try response.redirect(requestPath + "/")
                        } catch {
                            response.error = Error.failedToRedirectRequest(path: requestPath + "/", chainedError: error)
                        }
                    }
                } else {
                    serveFile(filePath, fileManager: fileManager, response: response)
                }
            } else {
                if let extensions = possibleExtensions {
                    for ext in extensions {
                        let newFilePath = filePath + "." + ext
                        if fileManager.fileExists(atPath: newFilePath, isDirectory: &isDirectory) {
                            if !isDirectory.boolValue {
                                serveFile(newFilePath, fileManager: fileManager, response: response)
                                break
                            }
                        }
                    }
                }
            }
        }
        r.next()
    }

    private func serveFile(_ filePath: String, fileManager: NSFileManager, response: RouterResponse) {
        // Check that no-one is using ..'s in the path to poke around the filesystem
        let tempAbsoluteBasePath = NSURL(fileURLWithPath: path).absoluteString
        let tempAbsoluteFilePath = NSURL(fileURLWithPath: filePath).absoluteString
        let absoluteBasePath = tempAbsoluteBasePath
        let absoluteFilePath = tempAbsoluteFilePath

        if  absoluteFilePath.hasPrefix(absoluteBasePath) {
            do {
                let attributes = try fileManager.attributesOfItem(atPath: filePath)
                response.setHeader("Cache-Control", value: "max-age=\(maxAgeCacheControlHeader)")
                if addLastModifiedHeader {
                    if let date = attributes[NSFileModificationDate] as? NSDate {
                        response.setHeader("Last-Modified", value: SPIUtils.httpDate(date))
                    }
                }
                if generateETag {
                    if let date = attributes[NSFileModificationDate] as? NSDate,
                        let size = attributes[NSFileSize] as? Int {
                            let sizeHex = String(size, radix: 16, uppercase: false)
                            let timeHex = String(Int(date.timeIntervalSince1970), radix: 16, uppercase: false)
                            let etag = "W/\"\(sizeHex)-\(timeHex)\""
                        response.setHeader("Etag", value: etag)
                    }
                }
                if let customResponseHeadersSetter = customResponseHeadersSetter {
                    customResponseHeadersSetter.setCustomResponseHeaders(response: response, filePath: filePath, fileAttributes: attributes)
                }

                try response.send(fileName: filePath)
            } catch {
                // Nothing
            }
            response.status(.OK)
        }
    }

    public enum Options {
        case possibleExtensions([String])
        case serveIndexForDir(Bool)
        case addLastModifiedHeader(Bool)
        case maxAgeCacheControlHeader(Int)
        case redirect(Bool)
        case customResponseHeadersSetter(ResponseHeadersSetter)
        case generateETag(Bool)
    }

}
