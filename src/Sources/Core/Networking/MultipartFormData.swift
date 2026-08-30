import Foundation

struct MultipartFormData {
    let boundary = "Bump-Boundary-\(UUID().uuidString)"
    private var data = Data()

    var contentType: String { "multipart/form-data; boundary=\(boundary)" }

    mutating func addField(name: String, value: String) {
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        append("\(value)\r\n")
    }

    mutating func addFile(name: String, filename: String, mimeType: String, fileData: Data) {
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
        append("Content-Type: \(mimeType)\r\n\r\n")
        data.append(fileData)
        append("\r\n")
    }

    func finalized() -> Data {
        var result = data
        result.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return result
    }

    private mutating func append(_ string: String) {
        data.append(string.data(using: .utf8)!)
    }
}

struct ImageUpload {
    let filename: String
    let mimeType: String
    let data: Data

    init(filename: String = "image.jpg", mimeType: String = "image/jpeg", data: Data) {
        self.filename = filename
        self.mimeType = mimeType
        self.data = data
    }
}
