//
//  NetworkService.swift
//  Currency converter
//
//  Created by Oleg Samoylov on 09/02/2018.
//  Copyright © 2018 Oleg Samoylov. All rights reserved.
//

import Foundation

class NetworkService {
    
    var allCurrencies: [String] = []
    
    /// Relates to selected currencies:
    /// keeps the currency "from" and the currency "to" strings.
    var selectedCurrencies = (baseCurrency: "", toCurrency: "")
    
    static let shared = NetworkService()
    
    private init() { }
    
    func requestCurrentCurrencyRate(_ mode: ConverterMode, completion: @escaping ((_ update: Update) -> Void)) {
        completion(.activityIndicator(true))
        completion(.label(""))
        
        switch mode {
        case .getAllCurrencies:
            allCurrencies = []
            completion(.pickers)
            
            self.retrieveCurrencyRate(baseCurrency: nil, toCurrency: nil) { [weak self] (value) in
                DispatchQueue.main.async(execute: {
                    if let strongSelf = self {
                        switch value {
                        case let .message(text):
                            completion(.label(text))
                            completion(.activityIndicator(false))
                        case let .currencies(array):
                            strongSelf.allCurrencies = array
                            completion(.pickers)
                            completion(.activityIndicator(false))
                            strongSelf.requestCurrentCurrencyRate(.exchangeCurrencies(strongSelf.allCurrencies[0], strongSelf.allCurrencies[1]), completion: completion)
                        }
                    }
                })
            }
        case let .exchangeCurrencies(baseCurrency, toCurrency):
            self.retrieveCurrencyRate(baseCurrency: baseCurrency, toCurrency: toCurrency) { [weak self] (value) in
                DispatchQueue.main.async(execute: {
                    if self != nil {
                        if case .message(let text) = value {
                            completion(.label(text))
                            completion(.activityIndicator(false))
                        }
                    }
                })
            }
        }
    }
    
    private func requestCurrencyRates(baseCurrency: String?, parseHandler: @escaping (Data?, Error?) -> Void) {
        let url: URL
        
        if let currency = baseCurrency {
            url = URL(string: "https://api.fixer.io/latest?base=" + currency)!
        } else {
            url = URL(string: "https://api.fixer.io/latest")!
        }
        
        let dataTask = URLSession.shared.dataTask(with: url) {
            (dataReceived, response, error) in
            parseHandler(dataReceived, error)
        }
        
        dataTask.resume()
    }
    
    private func parseCurrencyRatesResponse(data: Data?, toCurrency: String?) -> Response {
        var value = ""
        
        do {
            let json = try JSONSerialization.jsonObject(with: data!, options: []) as? Dictionary<String, Any>
            
            if let parsedJSON = json {
                print("\(parsedJSON)")
                
                if let rates = parsedJSON["rates"] as? Dictionary<String, Double> {
                    if let currency = toCurrency {
                        if let rate = rates[currency] {
                            value = "\(rate)"
                        } else {
                            value = "No rate for currency \"\(currency)\" found"
                        }
                    }
                    else {
                        var keysArray = Array(rates.keys)
                        // This line was added for EUR currency support
                        keysArray += [parsedJSON["base"] as! String]
                        return .currencies(keysArray.sorted())
                    }
                } else {
                    value = "No \"rates\" field found"
                }
            } else {
                value = "No JSON value parsed"
            }
        } catch {
            value = error.localizedDescription
        }
        
        return .message(value)
    }
    
    private func retrieveCurrencyRate(baseCurrency: String?, toCurrency: String?, completion: @escaping (Response) -> Void) {
        self.requestCurrencyRates(baseCurrency: baseCurrency) { [weak self] (data, error) in
            var response = Response.message("No currency retrieved!")
            
            if let currentError = error {
                response = .message(currentError.localizedDescription)
            } else {
                if let strongSelf = self {
                    if let currency = toCurrency {
                        response = strongSelf.parseCurrencyRatesResponse(data: data, toCurrency: currency)
                    } else {
                        completion(strongSelf.parseCurrencyRatesResponse(data: data, toCurrency: nil))
                        return
                    }
                }
            }
            
            completion(response)
        }
    }
    
    //MARK: - Enums
    
    /// Used to update the view from the model
    /// by completion handlers.
    enum Update {
        case activityIndicator(Bool)
        case pickers
        case label(String)
    }
    
    enum ConverterMode {
        case getAllCurrencies, exchangeCurrencies(String, String)
    }
    
    /// Used to select the response
    /// based on the request: get message text
    /// or list of all currencies.
    private enum Response {
        case message(String), currencies([String])
    }
    
}
