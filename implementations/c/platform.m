// The game is C. Only the macOS Sokol implementation and GPU capture need Obj-C.
#define SOKOL_IMPL
#include "sokol_app.h"
#include "sokol_gfx.h"
#include "sokol_glue.h"
#include "sokol_audio.h"
#include "sokol_log.h"
#include "sokol_time.h"
#include "util/sokol_gl.h"
#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>

bool platform_capture(sg_image image, const char *path) {
    // Read our own offscreen target; no desktop/screen-recording access needed.
    sg_mtl_image_info info = sg_mtl_query_image_info(image);
    id<MTLTexture> texture = (__bridge id<MTLTexture>)info.tex[info.active_slot];
    id<MTLCommandQueue> queue = (__bridge id<MTLCommandQueue>)sg_mtl_command_queue();
    NSUInteger pitch = ((texture.width * 4 + 255) / 256) * 256;
    id<MTLBuffer> buffer = [texture.device newBufferWithLength:pitch * texture.height
                                                       options:MTLResourceStorageModeShared];
    if (!buffer)
        return false;
    id<MTLCommandBuffer> command = [queue commandBuffer];
    id<MTLBlitCommandEncoder> blit = [command blitCommandEncoder];
    [blit copyFromTexture:texture
                     sourceSlice:0
                     sourceLevel:0
                    sourceOrigin:MTLOriginMake(0, 0, 0)
                      sourceSize:MTLSizeMake(texture.width, texture.height, 1)
                        toBuffer:buffer
               destinationOffset:0
          destinationBytesPerRow:pitch
        destinationBytesPerImage:pitch * texture.height];
    [blit endEncoding];
    [command commit];
    [command waitUntilCompleted];
    if (command.status != MTLCommandBufferStatusCompleted)
        return false;
    unsigned char *planes[5] = {buffer.contents, NULL, NULL, NULL, NULL};
    NSBitmapImageRep *bitmap =
        [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:planes
                                                pixelsWide:texture.width
                                                pixelsHigh:texture.height
                                             bitsPerSample:8
                                           samplesPerPixel:4
                                                  hasAlpha:YES
                                                  isPlanar:NO
                                            colorSpaceName:NSDeviceRGBColorSpace
                                              bitmapFormat:NSBitmapFormatAlphaNonpremultiplied
                                               bytesPerRow:pitch
                                              bitsPerPixel:32];
    NSData *png = [bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    return [png writeToFile:[NSString stringWithUTF8String:path] atomically:YES];
}
