"""An image as an sRGB float array, top row first, inside Blender (ffmpeg-free)."""
import bpy
import numpy as np


def load(path):
    im = bpy.data.images.load(path)
    im.colorspace_settings.name = "sRGB"
    w, h = im.size
    a = np.zeros(w * h * im.channels, np.float32)
    im.pixels.foreach_get(a)
    return a.reshape(h, w, im.channels)[::-1, :, :3].copy()
