import UIKit

class ViewController: UIViewController {
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var btnSegment: UIButton!

    private var imageName = "1011.png"
    private var image : UIImage?
    private let imageHelper = UIImageHelper()

    private lazy var module: TorchModule = {
        if let filePath = Bundle.main.path(forResource:
            "dfu-resnet34-two-pass_torchscript", ofType: "pt"),
            let module = TorchModule(fileAtPath: filePath) {
            return module
        } else {
            fatalError("Can't find the model file!")
        }
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        btnSegment.setTitle("Segment", for: .normal)
        image = UIImage(named: imageName)!
        imageView.image = image
    }

    @IBAction func doInfer(_ sender: Any) {
        btnSegment.isEnabled = false
        btnSegment.setTitle("Running the model...", for: .normal)
        let resizedImage = image!.resized(to: CGSize(width: 512, height: 512))
        guard let pixelBuffer = resizedImage.normalized() else {
            return
        }

        let w = Int32(resizedImage.size.width)
        let h = Int32(resizedImage.size.height)
        DispatchQueue.global().async {
            // https://github.com/pytorch/ios-demo-app/pull/76
            // UnsafeMutablePointer() doesn't guarantee that the converted pointer points to the memory that is still being allocated
            // So we create a new pointer and copy the &pixelBuffer's memory to where it points to
            let copiedBufferPtr = UnsafeMutablePointer<Float>.allocate(capacity: pixelBuffer.count)
            copiedBufferPtr.initialize(from: pixelBuffer, count: pixelBuffer.count)
            
            // return NSData to use Objective-C ARC
            let data = self.module.segment(image: copiedBufferPtr, withWidth:w, withHeight: h)
            
            // coerce NSData into a UnsafeMutablePointer<UInt8>
            let pointer = data.mutableBytes.assumingMemoryBound(to: UInt8.self)
            
            // send pointer back to Objective-C for conversion to UIImage
            let image = self.imageHelper.convertRGBBuffer(toUIImage: pointer, withWidth: w, withHeight: h)
            copiedBufferPtr.deallocate()

            DispatchQueue.main.async {
                self.imageView.image = image
                self.btnSegment.isEnabled = true
                self.btnSegment.setTitle("Segment", for: .normal)
            }
        }
    }

    @IBAction func doRestart(_ sender: Any) {
        if imageName == "1011.png" {
            imageName = "1014.png"
        }
        else {
            imageName = "1011.png"
        }
        image = UIImage(named: imageName)!
        imageView.image = image
    }
}
