//
//  ViewController.swift
//  EventSource
//
//  Created by Andres on 2/13/15.
//  Copyright (c) 2015 Inaka. All rights reserved.
//

import UIKit

struct IntfStats: Decodable {
  let name: String
  let rx: Int
  let tx: Int
}

struct LiveStatsData: Decodable {
  let intfStats: [IntfStats]
}
struct LiveStatsEvent: Decodable {
    let data: LiveStatsData
}

class ViewController: UIViewController {

    @IBOutlet fileprivate weak var status: UILabel!
    @IBOutlet fileprivate weak var dataLabel: UILabel!
    @IBOutlet fileprivate weak var nameLabel: UILabel!
    @IBOutlet fileprivate weak var idLabel: UILabel!
    @IBOutlet fileprivate weak var squareConstraint: NSLayoutConstraint!
    var eventSource: EventSource?

    override func viewDidLoad() {
        super.viewDidLoad()

        let serverURL = URL(string: "http://192.168.1.55:8834/v1/encipher/simple?command=get&item=liveStats&target=0.0.0.0&streaming=true")!
        eventSource = EventSource(url: serverURL, headers: ["Authorization": "Bearer basic-auth-token"])

        eventSource?.onOpen { [weak self] in
            self?.status.backgroundColor = UIColor(red: 166/255, green: 226/255, blue: 46/255, alpha: 1)
            self?.status.text = "CONNECTED"
        }

        eventSource?.onComplete { [weak self] statusCode, reconnect, error in
            self?.status.backgroundColor = UIColor(red: 249/255, green: 38/255, blue: 114/255, alpha: 1)
            self?.status.text = "DISCONNECTED"

            guard reconnect ?? false else { return }

            let retryTime = self?.eventSource?.retryTime ?? 3000
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(retryTime)) { [weak self] in
                self?.eventSource?.connect()
            }
        }

        eventSource?.onMessage { [weak self] id, event, data in
            self?.updateLabels(id, event: event, data: data)
        }

        eventSource?.addEventListener("liveStats") { [weak self] id, event, data in
            self?.updateLabels(id, event: event, data: data)
        }
    }

  func parseData(data: String?) -> String {
    let lse = try! JSONDecoder( ).decode(LiveStatsEvent.self, from: (data?.data(using: .utf8))!)
    var output = ""
    var intfStats = lse.data.intfStats
    intfStats = intfStats.sorted(by: { $0.name < $1.name })
    for intfStat in intfStats {
      output += "\(intfStat.name) tx: \(intfStat.tx) rx: \(intfStat.rx)\n"
    }
    
    return output;
  }
  
    func updateLabels(_ id: String?, event: String?, data: String?) {
        idLabel.text = id
        nameLabel.text = event
      dataLabel.text = parseData(data:data)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        let finalPosition = view.frame.size.width - 50

        squareConstraint.constant = 0
        view.layoutIfNeeded()

        let animationOptions: UIView.KeyframeAnimationOptions = [
            UIView.KeyframeAnimationOptions.repeat, UIView.KeyframeAnimationOptions.autoreverse
        ]

        UIView.animateKeyframes(withDuration: 2,
                                delay: 0,
                                options: animationOptions,
                                animations: { () in
            self.squareConstraint.constant = finalPosition
            self.view.layoutIfNeeded()
        }, completion: nil)
    }

    @IBAction func disconnect(_ sender: Any) {
        eventSource?.disconnect()
    }

    @IBAction func connect(_ sender: Any) {
        eventSource?.connect()
    }
}
