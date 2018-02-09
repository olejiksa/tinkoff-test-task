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
    
    //MARK: - UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.pickerTo.dataSource = self
        self.pickerFrom.dataSource = self
        
        self.pickerTo.delegate = self
        self.pickerFrom.delegate = self
        
        self.activityIndicator.hidesWhenStopped = true
        
        NetworkService.shared.requestCurrentCurrencyRate(.getAllCurrencies) { [weak self] (update: NetworkService.Update) in
            if let strongSelf = self {
                strongSelf.updateView(update)
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func updateView(_ update: NetworkService.Update) {
        switch update {
        case let .activityIndicator(isAnimating):
            if isAnimating {
                self.activityIndicator.startAnimating()
            } else {
                self.activityIndicator.stopAnimating()
            }
        case .pickers:
            self.pickerFrom.reloadAllComponents()
            self.pickerTo.reloadAllComponents()
        case let .label(text):
            self.label.text = text
        }
    }
    
    //MARK: - UIPickerView
    
    func currenciesExceptBase() -> [String] {
        var currenciesExceptBase = NetworkService.shared.allCurrencies
        currenciesExceptBase.remove(at: pickerFrom.selectedRow(inComponent: 0))
        
        return currenciesExceptBase
    }
    
    func selectedCurrencies() -> (String, String) {
        let baseCurrencyIndex = self.pickerFrom.selectedRow(inComponent: 0)
        let toCurrencyIndex = self.pickerTo.selectedRow(inComponent: 0)
        
        let baseCurrency = NetworkService.shared.allCurrencies[baseCurrencyIndex]
        let toCurrency = self.currenciesExceptBase()[toCurrencyIndex]
        
        NetworkService.shared.selectedCurrencies = (baseCurrency, toCurrency)
        
        return (baseCurrency, toCurrency)
    }
    
    //MARK: - UIPickerViewDataSource
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if !NetworkService.shared.allCurrencies.isEmpty && pickerView === pickerTo {
            return self.currenciesExceptBase().count
        }
        
        return NetworkService.shared.allCurrencies.count
    }
    
    //MARK: - UIPickerViewDelegate

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if !NetworkService.shared.allCurrencies.isEmpty && pickerView === pickerTo {
            return self.currenciesExceptBase()[row]
        }
        
        return NetworkService.shared.allCurrencies[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if pickerView === pickerFrom {
            self.pickerTo.reloadAllComponents()
        }
        
        NetworkService.shared.requestCurrentCurrencyRate(.exchangeCurrencies(selectedCurrencies().0, selectedCurrencies().1)) { [weak self] (update: NetworkService.Update) in
            if let strongSelf = self {
                strongSelf.updateView(update)
            }
        }
    }
    
    //MARK: - Extra features
    
    /// Refreshes currency list manually.
    @IBAction func refresh(_ sender: UIBarButtonItem) {
        NetworkService.shared.requestCurrentCurrencyRate(.getAllCurrencies) { [weak self] (update: NetworkService.Update) in
            if let strongSelf = self {
                strongSelf.updateView(update)
            }
        }
    }

}

