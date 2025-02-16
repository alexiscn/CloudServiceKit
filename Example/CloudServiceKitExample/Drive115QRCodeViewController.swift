//
//  Drive115QRCodeViewController.swift
//  CloudServiceKitExample
//
//  Created by alexis on 2025/2/16.
//

import UIKit
import CloudServiceKit
import OAuthSwift

class Drive115QRCodeViewController: UIViewController {
    
    var completionHandler: ((Drive115Connector.AccessTokenPayload) -> Void)?
    
    var cancellationHandler: (() -> Void)?
    
    private let imageView = UIImageView()
    
    private let textLabel = UILabel()
    
    private let connector: Drive115Connector
    
    private weak var timer: Timer?
    
    init(connector: Drive115Connector) {
        self.connector = connector
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupViews()
        generateQRCode()
    }
    
    private func setupViews() {
     
        view.backgroundColor = .systemBackground
        
        textLabel.numberOfLines = 0
        textLabel.text = "Scan the QRCode using 115 client to sign in"
        
        let stackView = UIStackView(arrangedSubviews: [imageView, textLabel])
        stackView.axis = .vertical
        stackView.spacing = 20
        
        view.addSubview(stackView)
        
        stackView.translatesAutoresizingMaskIntoConstraints = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor, multiplier: 1.0)
        ])
    }
    
    private func generateQRCode() {
        Task { @MainActor in
            do {
                let qrcode = try await connector.fetchAuthQRCode()
                if let filter = CIFilter(name: "CIQRCodeGenerator") {
                    filter.setValue(qrcode.qrcode.data(using: .ascii)!, forKey: "inputMessage")
                    let transform = CGAffineTransform(scaleX: 3, y: 3)
                    if let output = filter.outputImage?.transformed(by: transform) {
                        imageView.image = UIImage(ciImage: output)
                        
                        self.timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true, block: { [weak self] timer in
                            guard let self = self else { return }
                            self.checkQRCodeStatus(with: qrcode)
                        })
                    }
                }
                
            } catch {
                print(error)
            }
        }
    }
    
    private func checkQRCodeStatus(with qrcode: Drive115Connector.QRCode) {
        guard let codeVerifier = connector.codeVerifier else {
            return
        }
        Task { @MainActor in
            let result = try await connector.refreshAuthStatus(uid: qrcode.uid, time: qrcode.time, sign: qrcode.sign)
            if result.status == 2 {
                timer?.invalidate()
                timer = nil
                do {
                    let accessTokenPayload = try await connector.getAccessToken(uid: qrcode.uid, codeVerifier: codeVerifier)
                    completionHandler?(accessTokenPayload)
                } catch {
                    print(error)
                }
            }
        }
    }
}
