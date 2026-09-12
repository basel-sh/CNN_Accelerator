import sys, os, json
sys.path.insert(0, "Python")
sys.path.insert(0, ".")
import numpy as np
from image_generator import generate_test_image, generate_test_kernel
from utilities import from_twos_complement
import runner

def read_real_image_mem(path, h, w):
    vals = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line: continue
            vals.append(int(line, 16))
    return np.array(vals, dtype=np.int64).reshape(h, w)

real_img = read_real_image_mem("real_input_32x32.mem", 32, 32)

results = {}

# FUNC-01: identity kernel, real image, relu off
k_id = generate_test_kernel(3, "identity")
r = runner.run_generic("FUNC-01", real_img, k_id, relu=False)
results["FUNC-01"] = r["status"]

# FUNC-03: ReLU on, edge kernel, real image (same stimulus family as FUNC-02)
edge_img = read_real_image_mem("real_input_32x32.mem", 32, 32)
k_edge = np.array([[-1,-1,-1],[-1,8,-1],[-1,-1,-1]])
r = runner.run_generic("FUNC-03", edge_img, k_edge, relu=True)
results["FUNC-03"] = r["status"]

# FUNC-05: 10 random seeds
func05_all_pass = True
for seed in range(10):
    img = generate_test_image(32, 32, "random", seed, 8)
    ker = generate_test_kernel(3, "random", 8)
    relu = (seed % 2 == 0)
    r = runner.run_generic(f"FUNC-05-seed{seed}", img, ker, relu=relu)
    if r["status"] != "PASS":
        func05_all_pass = False
results["FUNC-05"] = "PASS" if func05_all_pass else "FAIL"

# FUNC-06: 64x64, random image + random 3x3 kernel
img64 = generate_test_image(64, 64, "random", 42, 8)
k64 = generate_test_kernel(3, "random", 8)
r = runner.run_generic("FUNC-06", img64, k64, relu=False, img_w=64, img_h=64, k=3)
results["FUNC-06"] = r["status"]

# FUNC-07: K=5, 32x32, random 5x5 kernel
img_k5 = generate_test_image(32, 32, "random", 43, 8)
k5 = generate_test_kernel(5, "random", 8)
r = runner.run_generic("FUNC-07", img_k5, k5, relu=False, img_w=32, img_h=32, k=5)
results["FUNC-07"] = r["status"]

# BND-01: 32x32 exact (competition floor), randomized content
img_b1 = generate_test_image(32, 32, "random", 100, 8)
k_b1 = generate_test_kernel(3, "random", 8)
r = runner.run_generic("BND-01", img_b1, k_b1, relu=False)
results["BND-01"] = r["status"]

# BND-02: K=3, Img=64x64 (smallest K, largest tested image)
img_b2 = generate_test_image(64, 64, "random", 101, 8)
k_b2 = generate_test_kernel(3, "random", 8)
r = runner.run_generic("BND-02", img_b2, k_b2, relu=False, img_w=64, img_h=64, k=3)
results["BND-02"] = r["status"]

# BND-03: all-zero image
img_zeros = generate_test_image(32, 32, "zeros", 0, 8)
k_b3 = generate_test_kernel(3, "random", 8)
r = runner.run_generic("BND-03", img_zeros, k_b3, relu=False)
results["BND-03"] = r["status"]

# BND-04: all-max (255) image
img_max = generate_test_image(32, 32, "max", 0, 8)
k_b4 = generate_test_kernel(3, "random", 8)
r = runner.run_generic("BND-04", img_max, k_b4, relu=False)
results["BND-04"] = r["status"]

# BND-05: checkerboard image
img_chk = generate_test_image(32, 32, "checkerboard", 0, 8)
k_b5 = k_edge
r = runner.run_generic("BND-05", img_chk, k_b5, relu=False)
results["BND-05"] = r["status"]

# BND-06: all-zero kernel, random image
img_b6 = generate_test_image(32, 32, "random", 102, 8)
k_zero = np.zeros((3,3), dtype=np.int64)
r = runner.run_generic("BND-06", img_b6, k_zero, relu=False)
results["BND-06"] = r["status"]

# BND-09: ReLU boundary exactly zero. Constant image + kernel whose 9 coeffs sum to 0 (edge_3x3) -> conv==0 everywhere.
img_const = np.full((32,32), 77, dtype=np.int64)
r = runner.run_generic("BND-09", img_const, k_edge, relu=True)
results["BND-09"] = r["status"]

# BND-10: spatial corner windows - distinguishing pixel at (0,0) and separately at (H-1,W-1)
k_box = generate_test_kernel(3, "box_blur", 8)
img_corner_a = np.zeros((32,32), dtype=np.int64); img_corner_a[0,0] = 200
img_corner_b = np.zeros((32,32), dtype=np.int64); img_corner_b[31,31] = 200
r1 = runner.run_generic("BND-10a", img_corner_a, k_box, relu=False)
r2 = runner.run_generic("BND-10b", img_corner_b, k_box, relu=False)
results["BND-10"] = "PASS" if (r1["status"]=="PASS" and r2["status"]=="PASS") else "FAIL"

runner.save()
with open("generic_results.json","w") as f:
    json.dump(results, f, indent=2)
for k,v in results.items():
    print(k, v)
