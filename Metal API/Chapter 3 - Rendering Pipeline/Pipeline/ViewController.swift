import Cocoa
import MetalKit

class ViewController: NSViewController {
  
  var renderer: Renderer?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    guard let metalView = view as? MTKView else {
      fatalError("metal view not set up in storyboard")
    }
    renderer = Renderer(metalView: metalView)
  }
}
