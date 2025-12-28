// ============ 数据结构定义 ============
struct SphereData {
    center:  vec3<f32>,
    radius: f32,
}

// ============ BindGroup 绑定 ============
// @group(0) @binding(0) - Uniform Buffer（读）
@group(0) @binding(0)
var<uniform> sphere: SphereData;

// @group(0) @binding(1) - Storage Texture（写）
@group(0) @binding(1)
var output_texture: texture_storage_2d<rgba8unorm, write>;

// ============ 光线结构体 ============
struct Ray {
    origin: vec3<f32>,
    direction: vec3<f32>,
}

// ============ 光线与球的交点判断函数 ============
fn ray_sphere_intersect(ray: Ray, sphere_center: vec3<f32>, sphere_radius: f32) -> bool {
    // 计算光线到球心的向量
    let oc = ray.origin - sphere_center;

    // 二次方程系数：ray.direction·ray.direction, 2·oc·ray.direction, oc·oc - r²
    let a = dot(ray.direction, ray.direction);
    let b = 2.0 * dot(oc, ray.direction);
    let c = dot(oc, oc) - sphere_radius * sphere_radius;

    // 计算判别式
    let discriminant = b * b - 4.0 * a * c;

    // 判别式 >= 0 表示相交
    return discriminant >= 0.0;
}

// ============ 计算光线颜色函数 ============
fn ray_color(ray: Ray) -> vec4<f32> {
    if (ray_sphere_intersect(ray, sphere.center, sphere.radius)) {
        return vec4<f32>(1.0, 0.0, 0.0, 1.0);  // 相交则显示红色
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