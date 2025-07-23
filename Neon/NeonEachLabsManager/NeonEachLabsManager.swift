//
//  File.swift
//
//
//  Created by Tuna Öztürk on 24.08.2024.
//

import Foundation

public class NeonEachLabsManager {
    
    public static func startTask(apiKey: String, flowId: String, parameters: [String: Any], webhookURL: String? = nil, completion: @escaping (String?) -> Void) {
        var wrappedParameters: [String: Any] = ["parameters": parameters]
        
        if let webhookURL = webhookURL {
            wrappedParameters["webhook_url"] = webhookURL
            print("✅ Webhook URL added: \(webhookURL)")
        } else {
            print("❌ No webhook URL provided")
        }
        
        print("📤 Final wrappedParameters: \(wrappedParameters)")
        
        let endpoint = NeonEachLabsEndpoint.startTask(flowId: flowId, parameters: wrappedParameters, apiKey: apiKey)
        
        sendRequest(endpoint: endpoint) { json in
            print("📥 API Response: \(json ?? [:])")
            guard let json = json else {
                completion(nil)
                return
            }
            let triggerId = self.parseTriggerId(from: json)
            print("🆔 Parsed triggerId: \(triggerId ?? "nil")")
            completion(triggerId)
        }
    }
    
    public static func startBulkTask(apiKey: String, flowId: String, parameters: [String: Any],count: Int = 0, completion: @escaping ([String]?) -> Void) {
        var wrappedParameters: [String: Any] = [
                    "parameters": parameters,
                    "count": count,
                ]
        
        let bulkEndpoint = NeonEachLabsEndpoint.startBulkTask(flowId: flowId, parameters: wrappedParameters, apiKey: apiKey)
        /*NeonEachLabsEndpoint.startTask(flowId: flowId, parameters: wrappedParameters, apiKey: apiKey)*/
        
        sendRequest(endpoint: bulkEndpoint) { jsons in
            guard let json = jsons else {
                completion(nil)
                return
            }
            let triggerIds = self.parseBulkTriggerIDs(from: json)
            completion(triggerIds)
        }
    }
    
    public static func getStatus(apiKey: String, flowId: String, triggerId: String, completion: @escaping ([String:Any]?) -> Void) {
        let endpoint = NeonEachLabsEndpoint.getStatus(flowId: flowId, triggerId: triggerId, apiKey: apiKey)
        sendRequest(endpoint: endpoint) { json in
            completion(json)
        }
    }
    
    private static func sendRequest(endpoint: NeonEachLabsEndpoint, completion: @escaping ([String : Any]?) -> Void) {
        let request = endpoint.request()
        
        print("🚀 === OUTGOING REQUEST DEBUG ===")
        print("URL: \(request.url?.absoluteString ?? "nil")")
        print("Method: \(request.httpMethod ?? "nil")")
        print("Headers: \(request.allHTTPHeaderFields ?? [:])")
        
        if let httpBody = request.httpBody {
            if let bodyString = String(data: httpBody, encoding: .utf8) {
                print("Body JSON: \(bodyString)")
            } else {
                print("Body: (unable to convert to string)")
            }
        } else {
            print("Body: nil")
        }
        print("================================")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            print("📥 === API RESPONSE DEBUG ===")
            
            if let error = error {
                print("❌ Network Error: \(error.localizedDescription)")
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📊 Status Code: \(httpResponse.statusCode)")
            }
            
            if let data = data {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📄 Response Body: \(responseString)")
                }
            }
            print("=============================")
            
            guard error == nil,
                  let response = response as? HTTPURLResponse,
                  let data = data else {
                completion(nil)
                return
            }
            
            let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            completion(json)
        }
        
        task.resume()
    }

    
    private static func parseTriggerId(from json: [String: Any]?) -> String? {
        return json?["trigger_id"] as? String
    }
    private static func parseBulkTriggerIDs(from json: [String: Any]?) -> [String]? {
        return json?["execution_ids"] as? [String]
    }
}

enum NeonEachLabsEndpoint {
    
    case startTask(flowId: String, parameters: [String: Any], apiKey: String)
    case getStatus(flowId: String, triggerId: String, apiKey: String)
    case startBulkTask(flowId: String, parameters: [String: Any], apiKey: String)
    var baseURL: String {
        return "https://flows.eachlabs.ai/api/v1/"
    }
    
    enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
    }
    
    var method: HTTPMethod {
        switch self {
        case .startTask:
            return .post
        case .getStatus:
            return .get
        case .startBulkTask:
            return.post
        }
    }
    
    var path: String {
        switch self {
        case .startTask(let flowId, _, _):
            return "\(flowId)/trigger"
        case .getStatus(let flowId, let triggerId, _):
            return "\(flowId)/executions/\(triggerId)"
        case .startBulkTask(let flowId, _, _):
            return "\(flowId)/bulk"
            
        }
    }
    
    var headers: [String: String]? {
        switch self {
        case .startTask(_, _, let apiKey), .getStatus(_, _, let apiKey), .startBulkTask(_,_, apiKey: let apiKey):
            return [
                "X-API-Key": apiKey,
                "Content-Type": "application/json"
            ]
        }
    }
    
    func request() -> URLRequest {
        guard let url = URL(string: baseURL + path) else {
            fatalError("Invalid URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        switch self {
        case .startTask(_, let parameters, _):
            request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)
        case .getStatus:
            break
        case .startBulkTask(_, parameters: let parameters, _):
            request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)
        }
        
        return request
    }
}
