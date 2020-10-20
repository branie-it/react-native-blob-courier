//  Copyright (c) Ely Deckers.
// 
//  This source code is licensed under the MPL-2.0 license found in the
//  LICENSE file in the root directory of this source tree.
import Foundation

@objc(BlobCourier)
open class BlobCourier: NSObject {

 static let downloadTypeUnmanaged  = "Unmanaged"

  static let libraryDomain  = "io.deckers.blob_courier"

  static let parameterFilename = "filename"
  static let parameterFilePath = "filePath"
  static let parameterMethod = "method"
  static let parameterTaskId = "taskId"
  static let parameterUrl = "url"

  static let defaultMethod = "GET"

  static let requiredParameterProcessor = [
    "Boolean": { (input: NSDictionary, parameterName: String) in return input[parameterName]! },
    "String": { (input: NSDictionary, parameterName: String) in return input[parameterName]! }
  ]

  func assertRequiredParameter(input: NSDictionary, type: String, parameterName: String) throws {
    let maybeValue = try
      (BlobCourier.requiredParameterProcessor[type] ?? { (_, _) in
        throw BlobCourierErrors.BlobCourierError.withMessage(
          code: BlobCourierErrors.errorMissingRequiredParameter,
          message:
            "No processor defined for type `\(type)`, valid options: \(BlobCourier.requiredParameterProcessor.keys)"
        )
      })(input, parameterName)

    if maybeValue == nil {
      throw BlobCourierErrors.BlobCourierError.withMessage(
        code: BlobCourierErrors.errorMissingRequiredParameter,
        message: "`\(parameterName)` is a required parameter of type `\(type)`")
    }
  }

  func fetchBlobFromValidatedParameters(
    input: NSDictionary,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) throws {
    let taskId = (input[BlobCourier.parameterTaskId] as? String) ?? ""

    let url = (input[BlobCourier.parameterUrl] as? String) ?? ""

    let urlObject = URL(string: url)

    let filename = (input[BlobCourier.parameterFilename] as? String) ?? ""

    let documentsUrl: URL =
      try FileManager.default.url(
        for: .documentDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: false)
    let destinationFileUrl = documentsUrl.appendingPathComponent(filename)

    let fileURL = URL(string: url)
    let sessionConfig = URLSessionConfiguration.default
    let downloaderDelegate =
      DownloaderDelegate(
        taskId: taskId,
        destinationFileUrl: destinationFileUrl,
        resolve: resolve,
        reject: reject)
    let session = URLSession(configuration: sessionConfig, delegate: downloaderDelegate, delegateQueue: nil)
    let request = URLRequest(url: fileURL!)

    session.downloadTask(with: request).resume()
  }

  func buildRequestDataForFileUpload(url: URL, fileUrl: URL) -> (URLRequest, Data) {
    // https://igomobile.de/2020/06/16/swift-upload-a-file-with-multipart-form-data-in-ios-using-uploadtask-and-urlsession/

    let boundary = UUID().uuidString

    var request = URLRequest(url: url)
    request.httpMethod = "POST"

    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

    let fileName = fileUrl.lastPathComponent
    let mimetype = "application/octet-stream"
    let paramName = "file"
    let fileData = try? Data(contentsOf: fileUrl)

    var data = Data()

    data.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
    data.append(
      "Content-Disposition: form-data; name=\"\(paramName)\"; filename=\"\(fileName)\"\r\n"
        .data(using: .utf8)!)
    data.append("Content-Type: \(mimetype)\r\n\r\n".data(using: .utf8)!)
    data.append(fileData!)
    data.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

    request.setValue(String(data.count), forHTTPHeaderField: "Content-Length")

    return (request, data)
  }

  func uploadBlobFromValidatedParameters(
    input: NSDictionary, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock
  ) throws {
    print("Start uploadBlobFromValidatedParameters")
    let taskId = (input[BlobCourier.parameterTaskId] as? String) ?? ""

    let url = (input[BlobCourier.parameterUrl] as? String) ?? ""

    let urlObject = URL(string: url)!

    let filePath = (input[BlobCourier.parameterFilePath] as? String) ?? ""

    let filePathObject = URL(string: filePath)!

    let sessionConfig = URLSessionConfiguration.default
    let uploaderDelegate = UploaderDelegate(taskId: taskId, resolve: resolve, reject: reject)
    let session = URLSession(configuration: sessionConfig, delegate: uploaderDelegate, delegateQueue: nil)

    let (request, fileData) = buildRequestDataForFileUpload(url: urlObject, fileUrl: filePathObject)

    session.uploadTask(with: request, from: fileData).resume()
  }

  @objc(fetchBlob:withResolver:withRejecter:)
  func fetchBlob(
    input: NSDictionary, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock
  ) {
    do {
      try assertRequiredParameter(
        input: input, type: "String", parameterName: BlobCourier.parameterFilename)
      try assertRequiredParameter(
        input: input, type: "String", parameterName: BlobCourier.parameterTaskId)
      try assertRequiredParameter(
        input: input, type: "String", parameterName: BlobCourier.parameterUrl)

      try fetchBlobFromValidatedParameters(input: input, resolve: resolve, reject: reject)
    } catch {
      print("\(error)")
    }
  }

  @objc(uploadBlob:withResolver:withRejecter:)
  func uploadBlob(
    input: NSDictionary,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    print("Start uploadBlob")
    do {
      try assertRequiredParameter(
        input: input, type: "String", parameterName: BlobCourier.parameterFilePath)
      try assertRequiredParameter(
        input: input, type: "String", parameterName: BlobCourier.parameterTaskId)
      try assertRequiredParameter(
        input: input, type: "String", parameterName: BlobCourier.parameterUrl)

      try uploadBlobFromValidatedParameters(input: input, resolve: resolve, reject: reject)
    } catch {
      print("\(error)")
    }
  }
}
