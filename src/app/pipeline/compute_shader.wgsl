// ============ 数据结构定义 ============
struct Sphere {
    center:  vec3<f32>,
    radius: f32,
}

// ============ BindGroup 绑定 ============
// @group(0) @binding(0) - Uniform Buffer（读）
@group(0) @binding(0)
var<storage, read> spheres: array<Sphere>;

// @group(0) @binding(1) - Storage Texture（写）
@group(0) @binding(1)
var output_texture: texture_storage_2d<rgba8unorm, write>;

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

// ============ 计算光线颜色函数 ============
fn ray_color(ray: Ray) -> vec4<f32> {
    // 场景中的球体
    for (var i: u32 = 0u; i < arrayLength(&spheres); i = i + 1u) {
        let sphere = spheres[i];
        let hit_sphere = hit_sphere(ray, 0.001, 1000.0, sphere);
        if (hit_sphere.t > 0.0) {
            let n = hit_sphere.normal;
            return 0.5 * vec4<f32>(n.x + 1.0, n.y + 1.0, n.z + 1.0, 1.0);
        }
    }

    // 背景颜色（渐变）上半天蓝色，下半白色
    let t = 0.5 * (normalize(ray.direction).y + 1.0);
    let background_color = mix(vec4<f32>(1.0, 1.0, 1.0, 1.0), vec4<f32>(0.5, 0.7, 1.0, 1.0), t);
    return background_color;
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

    // ============ 生成光线（从相机出发）============
    // 将像素坐标归一化到 [-1, 1] 范围
    let uv = vec2<f32>(f32(pixel_x), f32(pixel_y)) / vec2<f32>(f32(texture_size.x), f32(texture_size.y));
    let ndc = uv * 2.0 - 1.0;  // 归一化设备坐标

    // 简单的透视投影
    // 假设相机在 (0, 0, 3)，看向 (0, 0, 0)
    let camera_pos = vec3<f32>(0.0, 0.0, 3.0);
    let camera_target = vec3<f32>(0.0, 0.0, 0.0);

    // 光线方向（简化版本：沿着 NDC 方向扩展）
    let ray_direction = normalize(vec3<f32>(ndc. x, -ndc.y, -1.0));

    let ray = Ray(camera_pos, ray_direction);

    // ============ 获取光线颜色 ============
    let color = ray_color(ray);

    // 写入存储纹理
    textureStore(output_texture, vec2<i32>(i32(pixel_x), i32(pixel_y)), color);
}