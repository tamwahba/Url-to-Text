//
//  SimpleAdaptiveThresholdFilter.swift
//  Url to Text
//
//  Created by Tamer Wahba on 11/29/16.
//  Copyright © 2016 Tamer Wahba. All rights reserved.
//

import UIKit

fileprivate let kernelText = "kernel vec4 adaptiveThreshold(sampler image, float radius) {" +
    "vec2 dst = destCoord();" +
    "int r = int(radius);" +
    "for (int i = -r; i < r; i++) {" +
    "   for (int j = -r; j < r; j++) {" +
    "       " +
    "" +
    "" +
    "" +
    "" +
    "   }" +
    "}" +
    "return sample(image, samplerTransform(image, dst));" +
"}"

class SimpleAdaptiveThresholdFilter: CIFilter {
    
    private let kernel = CIKernel(string: kernelText)
    
    var inputImage: CIImage?
    
    override var outputImage: CIImage? {
        get {
            return kernel?.apply(withExtent: inputImage!.extent,
                                 roiCallback: {
                                    index, rect in
                                    return rect
            },
                                 arguments: [inputImage!, 10])
        }
    }

}
