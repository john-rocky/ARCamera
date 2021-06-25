//
//  TextCollectionViewCell.swift
//  vNUTS
//
//  Created by 間嶋大輔 on 2019/10/28.
//  Copyright © 2019 daisuke. All rights reserved.
//

import UIKit

class TextCollectionViewCell: UICollectionViewCell {
    static let identifer = "OthersCell"

    var HeadLabel = UILabel()
    var TextLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
       
        HeadLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        

//        TextLabel.lineBreakMode = .byCharWrapping
//        TextLabel.numberOfLines = 0
//        HeadLabel.sizeToFit()
//        TextLabel.sizeToFit()
//        self.addSubview(HeadLabel)
//        self.addSubview(TextLabel)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        HeadLabel.text = nil
        TextLabel.text = nil
    }
}
