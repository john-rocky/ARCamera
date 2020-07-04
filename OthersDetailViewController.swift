//
//  OthersDetailViewController.swift
//  vNUTS
//
//  Created by 間嶋大輔 on 2019/10/12.
//  Copyright © 2019 daisuke. All rights reserved.
//

import UIKit

class OthersDetailViewController: UIViewController,UICollectionViewDelegate,UICollectionViewDataSource {

    

    override func viewDidLoad() {
        super.viewDidLoad()
        OthersDetailTitle.text = othersDetailTitleText
        CollectionView.delegate = self
        CollectionView.dataSource = self
        // Do any additional setup after loading the view.
    
    }
    
    @IBOutlet weak var CollectionView: UICollectionView!
    
    @IBOutlet weak var OthersDetailTitle: UILabel!
    var othersDetailTitleText:String?
    var othersDetailContentsText:String?
    
    var othersDataSouce:[(String,String)] = []
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return othersDataSouce.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "OtherDetail", for: indexPath) as? OtherDetailCollectionViewCell
            else { preconditionFailure("Failed to load collection view cell") }
        cell.HeadLabel.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 25)
        cell.HeadLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        cell.TextLabel.frame = CGRect(x: 0, y: cell.HeadLabel.frame.maxY + 8, width: view.bounds.width - 40, height: view.bounds.height)
        cell.HeadLabel.text = NSLocalizedString(othersDataSouce[indexPath.item].0, comment: "")
        cell.TextLabel.text = NSLocalizedString(othersDataSouce[indexPath.item].1, comment: "")
        cell.TextLabel.numberOfLines = 0
        cell.TextLabel.lineBreakMode = .byCharWrapping
        cell.TextLabel.sizeToFit()
        return cell
    }
    
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
extension OthersDetailViewController: UICollectionViewDelegateFlowLayout {

func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
    let label = UILabel(frame: CGRect(x: 0, y: 0, width: view.bounds.width - 40, height: 20))
    let headLabel = UILabel(frame: CGRect(x: 0, y: 20, width: view.bounds.width - 40, height: 20))
    headLabel.text = othersDataSouce[indexPath.item].0
    label.text = othersDataSouce[indexPath.item].1
    headLabel.sizeToFit()
    label.numberOfLines = 0
    label.lineBreakMode = .byCharWrapping
    label.preferredMaxLayoutWidth = view.bounds.width - 40

    label.sizeToFit()
    return CGSize(width: self.view.bounds.width - 40, height: label.frame.height + headLabel.frame.height + 40)
    }
}

