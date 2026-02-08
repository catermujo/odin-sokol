/*
sokol_gfx_ext.h - local extensions for sokol_gfx
*/

#if defined(SOKOL_GFX_IMPL) && !defined(SOKOL_GFX_EXT_IMPL)
#define SOKOL_GFX_EXT_IMPL
#endif

#ifndef SOKOL_GFX_EXT_INCLUDED
#define SOKOL_GFX_EXT_INCLUDED

#ifndef SOKOL_GFX_INCLUDED
#error "Please include sokol_gfx.h before sokol_gfx_ext.h"
#endif

#include <stdbool.h>
#include <stdint.h>
#include <string.h>

#ifdef __cplusplus
extern "C" {
#endif

SOKOL_GFX_API_DECL void sg_query_image_pixels(sg_image img_id, void* pixels, int size);
SOKOL_GFX_API_DECL void sg_query_pixels(int x, int y, int w, int h, bool origin_top_left, void* pixels, int size);
SOKOL_GFX_API_DECL void sg_update_texture_filter(sg_image img_id, sg_filter min_filter, sg_filter mag_filter);

#ifdef __cplusplus
} // extern "C"
#endif

#endif // SOKOL_GFX_EXT_INCLUDED

#ifdef SOKOL_GFX_EXT_IMPL
#ifndef SOKOL_GFX_EXT_IMPL_INCLUDED
#define SOKOL_GFX_EXT_IMPL_INCLUDED

#ifndef SOKOL_GFX_IMPL_INCLUDED
#error "Please include sokol_gfx.h implementation before sokol_gfx_ext.h implementation"
#endif

#if defined(_SOKOL_ANY_GL)

static void _sgext_gl_query_image_pixels(_sg_image_t* img, void* pixels) {
    SOKOL_ASSERT(img);
    SOKOL_ASSERT(img->gl.target == GL_TEXTURE_2D);
    SOKOL_ASSERT(0 != img->gl.tex[img->cmn.active_slot]);
#if defined(SOKOL_GLCORE)
    _sg_gl_cache_store_texture_sampler_binding(0);
    _sg_gl_cache_bind_texture_sampler(0, img->gl.target, img->gl.tex[img->cmn.active_slot], 0);
    glGetTexImage(img->gl.target, 0, GL_RGBA, GL_UNSIGNED_BYTE, pixels);
    _SG_GL_CHECK_ERROR();
    _sg_gl_cache_restore_texture_sampler_binding(0);
#else
    static GLuint sgext_fbo = 0;
    GLint old_fbo = 0;
    if (0 == sgext_fbo) {
        glGenFramebuffers(1, &sgext_fbo);
    }
    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &old_fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, sgext_fbo);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, img->gl.tex[img->cmn.active_slot], 0);
    #if !defined(SOKOL_GLES2)
    glReadBuffer(GL_COLOR_ATTACHMENT0);
    #endif
    glReadPixels(0, 0, img->cmn.width, img->cmn.height, GL_RGBA, GL_UNSIGNED_BYTE, pixels);
    glBindFramebuffer(GL_FRAMEBUFFER, (GLuint) old_fbo);
    _SG_GL_CHECK_ERROR();
#endif
}

static void _sgext_gl_query_pixels(int x, int y, int w, int h, bool origin_top_left, void* pixels) {
    SOKOL_ASSERT(pixels);
    GLint gl_fb = 0;
    GLint dims[4];
    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &gl_fb);
    glGetIntegerv(GL_VIEWPORT, dims);
    y = origin_top_left ? (dims[3] - (y + h)) : y;
    #if !defined(SOKOL_GLES2)
    GLint old_read_buffer = 0;
    glGetIntegerv(GL_READ_BUFFER, &old_read_buffer);
    glReadBuffer(gl_fb == 0 ? GL_BACK : GL_COLOR_ATTACHMENT0);
    #endif
    glReadPixels(x, y, w, h, GL_RGBA, GL_UNSIGNED_BYTE, pixels);
    #if !defined(SOKOL_GLES2)
    glReadBuffer((GLenum) old_read_buffer);
    #endif
    _SG_GL_CHECK_ERROR();
}

static void _sgext_gl_update_texture_filter(_sg_image_t* img, sg_filter min_filter, sg_filter mag_filter) {
    SOKOL_ASSERT(img);
    SOKOL_ASSERT(0 != img->gl.tex[img->cmn.active_slot]);
    _sg_gl_cache_store_texture_sampler_binding(0);
    _sg_gl_cache_bind_texture_sampler(0, img->gl.target, img->gl.tex[img->cmn.active_slot], 0);
    const GLenum gl_min_filter = _sg_gl_min_filter(min_filter, SG_FILTER_NEAREST);
    const GLenum gl_mag_filter = _sg_gl_mag_filter(mag_filter);
    glTexParameteri(img->gl.target, GL_TEXTURE_MIN_FILTER, (GLint) gl_min_filter);
    glTexParameteri(img->gl.target, GL_TEXTURE_MAG_FILTER, (GLint) gl_mag_filter);
    _sg_gl_cache_restore_texture_sampler_binding(0);
}

#elif defined(SOKOL_METAL)

#import <Metal/Metal.h>

static bool _sgext_mtl_is_bgra(MTLPixelFormat fmt) {
    switch (fmt) {
        case MTLPixelFormatBGRA8Unorm:
        case MTLPixelFormatBGRA8Unorm_sRGB:
            return true;
        default:
            return false;
    }
}

static bool _sgext_mtl_is_rgba_or_bgra8(MTLPixelFormat fmt) {
    switch (fmt) {
        case MTLPixelFormatRGBA8Unorm:
        case MTLPixelFormatRGBA8Unorm_sRGB:
        case MTLPixelFormatBGRA8Unorm:
        case MTLPixelFormatBGRA8Unorm_sRGB:
            return true;
        default:
            return false;
    }
}

static void _sgext_copy_pixels_rgba8(const uint8_t* src, int src_row_pitch, uint8_t* dst, int width, int height, bool src_is_bgra) {
    SOKOL_ASSERT(src);
    SOKOL_ASSERT(dst);
    for (int y = 0; y < height; y++) {
        const uint8_t* s = src + (src_row_pitch * y);
        uint8_t* d = dst + ((width * 4) * y);
        if (!src_is_bgra) {
            memcpy(d, s, (size_t)(width * 4));
        } else {
            for (int x = 0; x < width; x++) {
                d[4 * x + 0] = s[4 * x + 2];
                d[4 * x + 1] = s[4 * x + 1];
                d[4 * x + 2] = s[4 * x + 0];
                d[4 * x + 3] = s[4 * x + 3];
            }
        }
    }
}

static void _sgext_mtl_query_image_pixels(_sg_image_t* img, void* pixels) {
    SOKOL_ASSERT(img);
    SOKOL_ASSERT(pixels);
    // Readback cannot safely happen while a pass is open in this backend state model.
    SOKOL_ASSERT(!_sg.cur_pass.in_pass);
    // If there is an in-flight frame command buffer, force users to query after sg_commit().
    SOKOL_ASSERT(nil == _sg.mtl.cmd_buffer);

    const int slot = img->cmn.active_slot;
    id<MTLTexture> src_tex = _sg_mtl_id(img->mtl.tex[slot]);
    SOKOL_ASSERT(src_tex != nil);
    SOKOL_ASSERT(_sgext_mtl_is_rgba_or_bgra8(src_tex.pixelFormat));

    const int w = (int) src_tex.width;
    const int h = (int) src_tex.height;
    const int bytes_per_row = w * 4;
    const int bytes_total = bytes_per_row * h;

    MTLTextureDescriptor* dst_desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:src_tex.pixelFormat width:(NSUInteger)w height:(NSUInteger)h mipmapped:NO];
    #if defined(_SG_TARGET_MACOS)
    dst_desc.storageMode = MTLStorageModeManaged;
    dst_desc.resourceOptions = MTLResourceStorageModeManaged;
    #else
    dst_desc.storageMode = MTLStorageModeShared;
    dst_desc.resourceOptions = MTLResourceStorageModeShared;
    #endif
    dst_desc.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
    id<MTLTexture> dst_tex = [_sg.mtl.device newTextureWithDescriptor:dst_desc];
    SOKOL_ASSERT(dst_tex != nil);

    id<MTLCommandBuffer> cmd_buf = [_sg.mtl.cmd_queue commandBuffer];
    id<MTLBlitCommandEncoder> blit = [cmd_buf blitCommandEncoder];
    [blit copyFromTexture:src_tex
              sourceSlice:0
              sourceLevel:0
             sourceOrigin:MTLOriginMake(0, 0, 0)
               sourceSize:MTLSizeMake((NSUInteger)w, (NSUInteger)h, 1)
                toTexture:dst_tex
         destinationSlice:0
         destinationLevel:0
        destinationOrigin:MTLOriginMake(0, 0, 0)];
    #if defined(_SG_TARGET_MACOS)
    [blit synchronizeTexture:dst_tex slice:0 level:0];
    #endif
    [blit endEncoding];
    [cmd_buf commit];
    [cmd_buf waitUntilCompleted];

    uint8_t* tmp = (uint8_t*) _sg_malloc((size_t) bytes_total);
    SOKOL_ASSERT(tmp);
    [dst_tex getBytes:tmp bytesPerRow:(NSUInteger)bytes_per_row fromRegion:MTLRegionMake2D(0, 0, (NSUInteger)w, (NSUInteger)h) mipmapLevel:0];
    _sgext_copy_pixels_rgba8(tmp, bytes_per_row, (uint8_t*) pixels, w, h, _sgext_mtl_is_bgra(src_tex.pixelFormat));
    _sg_free(tmp);
    _SG_OBJC_RELEASE(dst_tex);
}

static void _sgext_mtl_query_pixels(int x, int y, int w, int h, bool origin_top_left, void* pixels) {
    // A portable way to read from the active framebuffer in this backend isn't cheap.
    // Prefer sg_query_image_pixels() on an attachment image in higher-level code.
    _SOKOL_UNUSED(x);
    _SOKOL_UNUSED(y);
    _SOKOL_UNUSED(w);
    _SOKOL_UNUSED(h);
    _SOKOL_UNUSED(origin_top_left);
    SOKOL_ASSERT(pixels);
}

static void _sgext_mtl_update_texture_filter(_sg_image_t* img, sg_filter min_filter, sg_filter mag_filter) {
    // Filters are described by separate sampler objects in current sokol_gfx.
    _SOKOL_UNUSED(img);
    _SOKOL_UNUSED(min_filter);
    _SOKOL_UNUSED(mag_filter);
}

#endif

void sg_query_image_pixels(sg_image img_id, void* pixels, int size) {
    SOKOL_ASSERT(pixels);
    SOKOL_ASSERT(img_id.id != SG_INVALID_ID);
    _sg_image_t* img = _sg_lookup_image(img_id.id);
    SOKOL_ASSERT(img);
    SOKOL_ASSERT(size >= (img->cmn.width * img->cmn.height * 4));
    _SOKOL_UNUSED(size);
#if defined(_SOKOL_ANY_GL)
    _sgext_gl_query_image_pixels(img, pixels);
#elif defined(SOKOL_METAL)
    _sgext_mtl_query_image_pixels(img, pixels);
#else
    memset(pixels, 0, (size_t)size);
#endif
}

void sg_query_pixels(int x, int y, int w, int h, bool origin_top_left, void* pixels, int size) {
    SOKOL_ASSERT(pixels);
    SOKOL_ASSERT(w > 0);
    SOKOL_ASSERT(h > 0);
    SOKOL_ASSERT(size >= (w * h * 4));
    _SOKOL_UNUSED(size);
#if defined(_SOKOL_ANY_GL)
    _sgext_gl_query_pixels(x, y, w, h, origin_top_left, pixels);
#elif defined(SOKOL_METAL)
    _sgext_mtl_query_pixels(x, y, w, h, origin_top_left, pixels);
#else
    memset(pixels, 0, (size_t)size);
#endif
}

void sg_update_texture_filter(sg_image img_id, sg_filter min_filter, sg_filter mag_filter) {
    SOKOL_ASSERT(img_id.id != SG_INVALID_ID);
    _sg_image_t* img = _sg_lookup_image(img_id.id);
    SOKOL_ASSERT(img);
#if defined(_SOKOL_ANY_GL)
    _sgext_gl_update_texture_filter(img, min_filter, mag_filter);
#elif defined(SOKOL_METAL)
    _sgext_mtl_update_texture_filter(img, min_filter, mag_filter);
#else
    _SOKOL_UNUSED(min_filter);
    _SOKOL_UNUSED(mag_filter);
#endif
}

#endif // SOKOL_GFX_EXT_IMPL_INCLUDED
#endif // SOKOL_GFX_EXT_IMPL
