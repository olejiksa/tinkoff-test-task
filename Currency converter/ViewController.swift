//
//  ViewController.swift
//  Currency converter
//
//  Created by Oleg Samoylov on 08/02/2018.
//  Copyright © 2018 Oleg Samoylov. All rights reserved.
//

import UIKit

class ViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate {

    @IBOutlet weak var label: UILabel!
    
    @IBOutlet weak var pickerFrom: UIPickerView!
    @IBOutlet weak var pickerTo: UIPickerView!
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    var currencies: [String] = []
    
    //MARK: - UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.pickerTo.dataSource = self
        self.pickerFrom.dataSource = self
        
        self.pickerTo.delegate = self
        self.pickerFrom.delegate = self
        
        self.activityIndicator.hidesWhenStopped = true
        
        self.requestCurrentCurrencyRate(.getAllCurrencies)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //MARK: - UIPickerView
    
    func currenciesExceptBase() -> [String] {
        var currenciesExceptBase = currencies
        currenciesExceptBase.remove(at: pickerFrom.selectedRow(inComponent: 0))
        
        return currenciesExceptBase
    }
    
    //MARK: - UIPickerViewDataSource
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if !currencies.isEmpty && pickerView === pickerTo {
            return self.currenciesExceptBase().count
        }
        
        return currencies.count
    }
    
    //MARK: - UIPickerViewDelegate

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if !currencies.isEmpty && pickerView === pickerTo {
            return self.currenciesExceptBase()[row]
        }
        
        return currencies[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if pickerView === pickerFrom {
            self.pickerTo.reloadAllComponents()
        }
        
        self.requestCurrentCurrencyRateToExchange()
    }
    
    //MARK: - Network
    
    func requestCurrencyRates(baseCurrency: String?, parseHandler: @escaping (Data?, Error?) -> Void) {
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
    
    func requestCurrentCurrencyRate(_ mode: ConverterMode) {
        self.activityIndicator.startAnimating()
        self.label.text = ""
        
        switch mode {
        case .getAllCurrencies:
            currencies = []
            self.pickerFrom.reloadAllComponents()
            self.pickerTo.reloadAllComponents()
            
            self.retrieveCurrencyRate(baseCurrency: nil, toCurrency: nil) { [weak self] (value) in
                DispatchQueue.main.async(execute: {
                    if let strongSelf = self {
                        switch value {
                        case let .message(text):
                            strongSelf.label.text = text
                            
                            strongSelf.activityIndicator.stopAnimating()
                        case let .currencies(array):
                            strongSelf.currencies = array
                            strongSelf.pickerFrom.reloadAllComponents()
                            strongSelf.pickerTo.reloadAllComponents()
                            
                            strongSelf.activityIndicator.stopAnimating()
                            strongSelf.requestCurrentCurrencyRateToExchange()
                        }
                    }
                })
            }
        case let .exchangeCurrencies(baseCurrency, toCurrency):
            self.retrieveCurrencyRate(baseCurrency: baseCurrency, toCurrency: toCurrency) { [weak self] (value) in
                DispatchQueue.main.async(execute: {
                    if let strongSelf = self {
                        if case .message(let text) = value {
                            strongSelf.label.text = text
                            strongSelf.activityIndicator.stopAnimating()
                        }
                    }
                })
            }
        }
    }
    
    func requestCurrentCurrencyRateToExchange() {
        let baseCurrencyIndex = self.pickerFrom.selectedRow(inComponent: 0)
        let toCurrencyIndex = self.pickerTo.selectedRow(inComponent: 0)
        
        let baseCurrency = self.currencies[baseCurrencyIndex]
        let toCurrency = self.currenciesExceptBase()[toCurrencyIndex]
        
        self.requestCurrentCurrencyRate(.exchangeCurrencies(baseCurrency, toCurrency))
    }
    
    func parseCurrencyRatesResponse(data: Data?, toCurrency: String?) -> ConverterResponse {
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
    
    func retrieveCurrencyRate(baseCurrency: String?, toCurrency: String?, completion: @escaping (ConverterResponse) -> Void) {
        self.requestCurrencyRates(baseCurrency: baseCurrency) { [weak self] (data, error) in
            var response = ConverterResponse.message("No currency retrieved!")
            
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
    
    enum ConverterMode {
        case getAllCurrencies
        case exchangeCurrencies(String, String)
    }
    
    enum ConverterResponse {
        case message(String)
        case currencies([String])
    }
    
    //MARK: - Extra features
    
    @IBAction func refresh(_ sender: UIBarButtonItem) {
        self.requestCurrentCurrencyRate(.getAllCurrencies)
    }

}

