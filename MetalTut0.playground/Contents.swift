//live views in the assistant editor
import PlaygroundSupport
//Metal Framework
import MetalKit

//Check for suitable GPU by creating a device
guard let device = MTLCreateSystemDefaultDevice()else{
    fatalError(" ## Metal Output ## GPU is not Supported ")
}

//Setup the view
let frame = CGRect( x: 0, y : 0, width: 600, height: 600 )

//MTKView is a subClass of NSView on macOS and of UIView on iOS
let view  = MTKView(frame: frame, device: device)
//MTLClearColor represents anRGBA value
view.clearColor = MTLClearColor( red:1, green: 1, blue: 0.8, alpha: 1 )

// Manage the memory for the mesh data
let allocator = MTKMeshBufferAllocator(device: device)

// Model I/O creates a sphere with the specified size and returns a MDLMesh
// with all the vertex info in buffers
// Tut_1
/*let mdlMesh = MDLMesh( sphereWithExtent: [0.75,0.75,0.75], segments:[100,100], inwardNormals: false, geometryType: .triangles, allocator: allocator )*/
//Tut_2
let mdlMesh = MDLMesh( coneWithExtent: [1,1,1], segments: [10,10], inwardNormals: false, cap: true, geometryType: .triangles, allocator: allocator )

// For Metal to be able to use the mesh, convert it from a Model I/O mesh to
// MetalKit mesh
let mesh = try MTKMesh(mesh: mdlMesh, device: device)

// Organize the Command buffer
guard let commandQueue = device.makeCommandQueue() else {
    fatalError(" ## Metal Output ## Could not create a command queue ")
}

/// Shader Part
let shader = """
#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float4 position [[attribute(0)]];
};

//a vertex function, manipulate vertex positions
vertex float4 vertex_main(const VertexIn vertex_in [[ stage_in ]]) {
    return vertex_in.position;
}

//specify the pixel color
fragment float4 fragment_main(){
    return float4( 1, 0, 0, 1 );
}
"""

//Metal library contains these two funcs
let library = try device.makeLibrary(source: shader, options: nil)
let vertexFunction = library.makeFunction(name: "vertex_main")
let fragmentFunction = library.makeFunction(name: "fragment_main")

// Setup a pipeline state for the GPU
// Don't create a pipeline state directly, rather you create it through a descriptor
// Setup the descriptor with the correct shader funcs and a vertex descriptor
let descriptor = MTLRenderPipelineDescriptor()
descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
// how the vertices are laid out in a Metal buffer
descriptor.vertexFunction = vertexFunction
descriptor.fragmentFunction = fragmentFunction
//create a vertex descriptor when it loaded the sphere mesh
descriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(mesh.vertexDescriptor)

//create the pipeline state from the descriptor
let pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)

// MTKView provides a render pass descriptor and a drawable
guard let commandBuffer = commandQueue.makeCommandBuffer(), // a command buffer, stores all the commands
let descriptor = view.currentRenderPassDescriptor,//data for a number of render desinations,used to create the render command encoder
let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else{//Hold all the info to send to the GPU
    fatalError("")
}

renderEncoder.setRenderPipelineState(pipelineState)

// the sphere mesh holds a buffer containing a simple list of vertices
// give this buffer to the render encoder
// offset: the pos in the buffer where the vertex info starts
// index: the GPU vertex shader func will locate this buffer
renderEncoder.setVertexBuffer(mesh.vertexBuffers[0].buffer,offset: 0, index: 0)

guard let submesh = mesh.submeshes.first else {
    fatalError()
}

//Drawing
//renderEncoder.setTriangleFillMode(.lines)

renderEncoder.drawIndexedPrimitives( type: .line,
                                    indexCount: submesh.indexCount,
                                    indexType: submesh.indexType,
                                    indexBuffer: submesh.indexBuffer.buffer,
                                    indexBufferOffset: 0 )

// send command to the render command encoder and finalize the frame

// no more draw calls
renderEncoder.endEncoding()
// get the drawable from the MTKView
guard let drawable = view.currentDrawable else {
    fatalError()
}
commandBuffer.present(drawable)
commandBuffer.commit()

let asset = MDLAsset()
asset.add(mdlMesh)

let fileExt = "obj"
guard MDLAsset.canExportFileExtension(fileExt) else{
    fatalError(" ## Metal Output ## Can't export a .\(fileExt) format ")
}

do{
    let url = playgroundSharedDataDirectory.appendingPathComponent("primitive.\(fileExt)")
    try asset.export(to: url)
}catch{
    fatalError(" Error \(error.localizedDescription)")
}

PlaygroundPage.current.liveView = view


























