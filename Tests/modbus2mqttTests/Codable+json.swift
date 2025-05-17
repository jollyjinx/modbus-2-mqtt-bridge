public extension Encodable
{
    var json: String
    {
        let jsonEncoder = JSONEncoder()
        jsonEncoder.outputFormatting = [.sortedKeys]
        jsonEncoder.dateEncodingStrategy = .iso8601
        jsonEncoder.outputFormatting = [.prettyPrinted]
        let jsonData = try? jsonEncoder.encode(self)
        return jsonData != nil ? String(data: jsonData!, encoding: .utf8) ?? "" : ""
    }
}

public extension Decodable
{
    init(json: String) throws
    {
        print("Decodable:\(json)")
        print("Self:\(Self.self)")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = json.data(using: .utf8)!
        self = try decoder.decode(Self.self, from: data)
    }
}
