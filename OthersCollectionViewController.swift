//
//  OthersCollectionViewController.swift
//  vNUTS
//
//  Created by 間嶋大輔 on 2019/10/10.
//  Copyright © 2019 daisuke. All rights reserved.
//

import UIKit

private let reuseIdentifier = "Cell"

class OthersCollectionViewController: UICollectionViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Register cell classes
        self.collectionView!.register(UICollectionViewCell.self, forCellWithReuseIdentifier: reuseIdentifier)

        // Do any additional setup after loading the view.
        self.navigationItem.title = NSLocalizedString("HELP",value: "HELP", comment: "")
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.font :UIFont(name: "Helvetica", size: 17)!,
        NSAttributedString.Key.foregroundColor:UIColor.black]
    }
    var otherMenusImage:[UIImage?] = [UIImage(systemName: "photo.on.rectangle") ?? nil,UIImage(systemName: "person.and.person.fill") ?? nil,UIImage(systemName: "doc.text") ?? nil,UIImage(systemName: "doc.text") ?? nil]
    var otherMenus = ["ヘルプ","利用規約","プライバシーポリシー"]
    var othersDetailTitle:String?
    var othersDetailContents:String?
    var othersText = OthersText()
    var isMulti = false
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showOthersDetail" {
            if let odvc = segue.destination as? OthersDetailViewController {
                odvc.othersDetailTitleText = othersDetailTitle
                if let indexPaths = collectionView.indexPathsForSelectedItems {
                    let indexPath = indexPaths[0].row
                    switch indexPath {
                    case 0:
                        if !isMulti{ odvc.othersDataSouce = othersText.magazinesHelp } else {
                            odvc.othersDataSouce = othersText.pipHelp
                        }
                    case 1:odvc.othersDataSouce = othersText.termsOfService
                    case 2:odvc.othersDataSouce = othersText.privacyPolicy
                    default: odvc.othersDetailContentsText = "preparing"
                    }
                    }
                }
            }
        
        // Get the new view controller using [segue destinationViewController].
        // Pass the selected object to the new view controller.
    }

    // MARK: UICollectionViewDataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }


    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of items
        return otherMenus.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "othersMenuCell", for: indexPath)
    
        // Configure the cell
    if let detailCell = cell as? OthersCollectionViewCell {
        let othersMenuText = NSLocalizedString(otherMenus[indexPath.item], comment: "")
        let othersMenuIcon = otherMenusImage[indexPath.item]
        detailCell.othersMenuLabel.text = othersMenuText
        detailCell.othersMenuIconView.image = othersMenuIcon
    }
        return cell
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        othersDetailTitle = NSLocalizedString(otherMenus[indexPath.item], comment: "")
        performSegue(withIdentifier: "showOthersDetail", sender: nil)
    }
    // MARK: UICollectionViewDelegate

    /*
    // Uncomment this method to specify if the specified item should be highlighted during tracking
    override func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    */

    /*
    // Uncomment this method to specify if the specified item should be selected
    override func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    */

    /*
    // Uncomment these methods to specify if an action menu should be displayed for the specified item, and react to actions performed on the item
    override func collectionView(_ collectionView: UICollectionView, shouldShowMenuForItemAt indexPath: IndexPath) -> Bool {
        return false
    }

    override func collectionView(_ collectionView: UICollectionView, canPerformAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        return false
    }

    override func collectionView(_ collectionView: UICollectionView, performAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) {
    
    }
    */

}
