import sys, os
sys.path.insert(0, "Python")
import numpy as np
from image_generator import generate_test_image, generate_test_kernel
from utilities import quantize_signed, quantize_unsigned, to_twos_complement_hex

def write_mem(arr, path, width, signed):
    flat = np.asarray(arr).flatten()
    with open(path, "w") as f:
        for v in flat:
            if signed:
                v = int(quantize_signed(np.array([v]), width)[0])
                f.write(to_twos_complement_hex(v, width) + "\n")
            else:
                v = int(quantize_unsigned(np.array([v]), width)[0])
                f.write(format(v, "0{}x".format((width+3)//4)) + "\n")

os.makedirs("mem", exist_ok=True)

rng_img = lambda seed, h=8, w=8: generate_test_image(w, h, "random", seed, 8)

# reload/switch (FUNC-04 / B2B-03)
img = generate_test_image(8, 8, "random", 500, 8)
kA = generate_test_kernel(3, "identity")
kB = generate_test_kernel(3, "random")
write_mem(img, "mem/reload_image.mem", 8, False)
write_mem(kA, "mem/reload_kernelA.mem", 8, True)
write_mem(kB, "mem/reload_kernelB.mem", 8, True)

# rst04
img1 = generate_test_image(8, 8, "random", 501, 8)
img2 = generate_test_image(8, 8, "random", 502, 8)
kx = generate_test_kernel(3, "sharpen")
write_mem(img1, "mem/rst04_image1.mem", 8, False)
write_mem(img2, "mem/rst04_image2.mem", 8, False)
write_mem(kx, "mem/rst04_kernel.mem", 8, True)

# b2b04
img_b = generate_test_image(8, 8, "random", 503, 8)
k_b = generate_test_kernel(3, "edge")
write_mem(img_b, "mem/b2b04_image.mem", 8, False)
write_mem(k_b, "mem/b2b04_kernel.mem", 8, True)

# tim02
img_t = generate_test_image(8, 8, "random", 504, 8)
k_t = generate_test_kernel(3, "edge")
write_mem(img_t, "mem/tim02_image.mem", 8, False)
write_mem(k_t, "mem/tim02_kernel.mem", 8, True)

# backpressure
img_bp = generate_test_image(8, 8, "random", 505, 8)
k_bp = generate_test_kernel(3, "box_blur")
write_mem(img_bp, "mem/bp_image.mem", 8, False)
write_mem(k_bp, "mem/bp_kernel.mem", 8, True)

print("stimulus generated")
