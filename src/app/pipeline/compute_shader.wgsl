// ============ 数据结构定义 ============
struct Sphere {
    center:  vec3<f32>,
    radius: f32,
}

// ============ BindGroup 绑定 ============
@group(0) @binding(0)
var output_texture: texture_storage_2d<rgba8unorm, write>;
//@group(0) @binding(1)
//var<uniform> seed: u32;
@group(0) @binding(2)
var<storage, read> spheres: array<Sphere>;

// =========== 全局变量 ============
var<private> seed: u32;

// =========== 随机数生成器 ============
fn rand() -> f32 {
    seed = seed * 747796405u + 2891336453u;
    var result: u32 = ((seed >> ((seed >> 28u) + 4u)) ^ seed) * 277803737u;
    result = (result >> 22u) ^ result;
    return f32(result) / 4294967296.0;
}

fn rand_range(min: f32, max: f32) -> f32 {
    return min + rand() * (max - min);
}

fn rand_int(min: i32, max: i32) -> f32 {
    return f32(min) + rand() * f32(max - min);
}

fn rand_vec3(min: f32, max: f32) -> vec3<f32> {
    return vec3<f32>(rand_range(min, max), rand_range(min, max), rand_range(min, max));
}

fn rand_vec3_default() -> vec3<f32> {
    return rand_vec3(0.0, 1.0);
}

fn rand_unit_vector() -> vec3<f32> {
    var p = vec3<f32>(0.0);
    loop {
        p = rand_vec3(-1.0, 1.0);
        let lensq = dot(p, p);
        if (1e-160 < lensq && lensq <= 1.0) {
            break;
        }
    }
    return normalize(p);
}

fn rand_on_hemisphere(normal: vec3<f32>) -> vec3<f32> {
    let in_unit_sphere = rand_unit_vector();
    if (dot(in_unit_sphere, normal) > 0.0) {
        return in_unit_sphere;
    } else {
        return -in_unit_sphere;
    }
}

// ============ 光线结构体 ============
struct Ray {
    origin: vec3<f32>,
    direction: vec3<f32>,
}

// ============ 区间结构体 ============
struct Interval {
    t_min: f32,
    t_max: f32,
}

fn size(interval: Interval) -> f32 {
    return interval.t_max - interval.t_min;
}

fn contains(interval: Interval, t: f32) -> bool {
    return t >= interval.t_min && t <= interval.t_max;
}

fn surrounds(interval: Interval, x: f32) -> bool {
    return interval.t_min < x && x < interval.t_max;
}

fn interval_clamp(interval: Interval, t: f32) -> f32 {
    return clamp(t, interval.t_min, interval.t_max);
}

// ============ 光线击中数据 ============
struct HitRecord {
    point3: vec3<f32>,
    normal: vec3<f32>,
    t: f32,
    front_face: bool,
}

fn set_face_normal(hit_record: HitRecord, ray: Ray, outward_normal: vec3<f32>) -> HitRecord {
    var hitrecord = hit_record;
    hitrecord.front_face = dot(ray.direction, outward_normal) < 0.0;
    hitrecord.normal = select(-outward_normal, outward_normal, hitrecord.front_face);
    return hitrecord;
}

fn hit_sphere(ray: Ray, ray_tmin: f32, ray_tmax: f32, sphere: Sphere) -> HitRecord {
    let sphere_center = sphere.center;
    let sphere_radius = sphere.radius;

    let oc = ray.origin - sphere_center;
    let a = dot(ray.direction, ray.direction);
    let half_b = dot(oc, ray.direction);
    let c = dot(oc, oc) - sphere_radius * sphere_radius;
    let discriminant = half_b * half_b - a * c;

    var hit_record: HitRecord;

    if (discriminant < 0.0) {
        return hit_record; // 没有击中
    }

    let sqrtd = sqrt(discriminant);

    // 找到最近的可接受根
    var root = (-half_b - sqrtd) / a;
    if (root < ray_tmin || root > ray_tmax) {
        root = (-half_b + sqrtd) / a;
        if (root < ray_tmin || root > ray_tmax) {
            return hit_record; // 没有击中
        }
    }

    hit_record.t = root;
    hit_record.point3 = ray.origin + hit_record.t * ray.direction;
    let outward_normal = (hit_record.point3 - sphere_center) / sphere_radius;
    hit_record = set_face_normal(hit_record, ray, outward_normal);

    return hit_record;
}

fn hit_world(ray: Ray, ray_tmin: f32, ray_tmax: f32) -> HitRecord {
    var closest_so_far = ray_tmax;
    var hit_record: HitRecord;

    for (var i: u32 = 0u; i < arrayLength(&spheres); i = i + 1u) {
        let sphere = spheres[i];
        let temp_record = hit_sphere(ray, ray_tmin, closest_so_far, sphere);
        if (temp_record.t > 0.0) {
            closest_so_far = temp_record.t;
            hit_record = temp_record;
        }
    }

    return hit_record;
}

// ============ 计算光线颜色函数 ============
fn ray_color(initial_ray: Ray) -> vec4<f32> {
    var ray = initial_ray;
    var color = vec4<f32>(1.0);
    let max_depth = 50u;

    // 递归反弹
    for (var depth: u32 = 0u; depth < max_depth; depth = depth + 1u) {
        let hit_record = hit_world(ray, 0.001, 1000.0);
        if (hit_record.t <= 0.0) {
            // 背景颜色（渐变）上半天蓝色，下半白色
            let t = 0.5 * (normalize(ray.direction).y + 1.0);
            let background_color = mix(vec4<f32>(1.0, 1.0, 1.0, 1.0), vec4<f32>(0.5, 0.7, 1.0, 1.0), t);
            return color * background_color;
        }
        let direction = hit_record.normal + rand_unit_vector();
        ray = get_ray(hit_record.point3, direction);
        color = color * 0.1;
    }
    return color;
}

// ============ 获取光线函数 ============
fn get_ray(origin: vec3<f32>, direction: vec3<f32>) -> Ray {
    let offset_range_min = -0.0025;
    let offset_range_max = 0.0025;
    let offset = vec3<f32>(rand_range(offset_range_min, offset_range_max), rand_range(offset_range_min, offset_range_max), 0.0);
    let sampler_direction = normalize(direction + offset);
    return Ray(origin, sampler_direction);
}

fn smaple_anti_aliasing(camera_pos: vec3<f32>, ray_direction: vec3<f32>) -> vec4<f32> {
    let samples_per_pixel = 100u;
    let pixel_sample_scale = 1.0 / f32(samples_per_pixel);
    var color = vec4<f32>(0.0, 0.0, 0.0, 1.0);
    for (var s: u32 = 0u; s < samples_per_pixel; s = s + 1u) {
        // 在像素内随机偏移
        let ray = get_ray(camera_pos, ray_direction);
        color = color + ray_color(ray);
    }
    color = color * pixel_sample_scale;
    return color;
}

// ============ 写入颜色函数 ============

fn write_color(color: vec4<f32>) -> vec4<f32> {
    // Gamma 校正
    let interval = Interval(0.0, 0.999);
    let r = interval_clamp(interval, color.r);
    let g = interval_clamp(interval, color.g);
    let b = interval_clamp(interval, color.b);
    return linear_to_gamma(vec4<f32>(r, g, b, 1.0));
}

fn linear_to_gamma(color: vec4<f32>) -> vec4<f32> {
    return vec4<f32>(sqrt(color.r), sqrt(color.g), sqrt(color.b), color.a);
}

// ============ 主计算函数 ============
@compute @workgroup_size(8, 8, 1)
fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
    let pixel_x = global_id.x;
    let pixel_y = global_id.y;

    // 获取纹理尺寸
    let texture_size = textureDimensions(output_texture);

    // 边界检查（防止越界）
    if (pixel_x >= texture_size. x || pixel_y >= texture_size.y) {
        return;
    }

    // 初始化随机数种子
    let pixel_index = pixel_x * texture_size.y + pixel_y + (pixel_x * pixel_y);
    seed = pixel_index;

    // ============ 生成光线（从相机出发）============
    // 将像素坐标归一化到 [-1, 1] 范围
    let uv = vec2<f32>(f32(pixel_x), f32(pixel_y)) / vec2<f32>(f32(texture_size.x), f32(texture_size.y));
    let ndc = uv * 2.0 - 1.0;  // 归一化设备坐标

    // 简单的透视投影
    // 假设相机在 (0, 0, 3)，看向 (0, 0, 0)
    let camera_pos = vec3<f32>(0.0, 0.0, 3.0);
    let camera_target = vec3<f32>(0.0, 0.0, 0.0);

    // 光线方向（简化版本：沿着 NDC 方向扩展）
    let ray_direction = normalize(vec3<f32>(ndc.x, -ndc.y, -1.0));

    // ============ 获取光线颜色 ============
    // 采样多次抗锯齿
    let color = smaple_anti_aliasing(camera_pos, ray_direction);
    // 单次采样
    // let ray = Ray(camera_pos, ray_direction);
    // let color = ray_color(ray);

    // 写入存储纹理
    textureStore(output_texture, vec2<i32>(i32(pixel_x), i32(pixel_y)), color);
}