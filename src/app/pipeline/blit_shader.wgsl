// ============ Sampler 和 Texture 绑定 ============
@group(0) @binding(0)
var texture_sampler: sampler;

@group(0) @binding(1)
var source_texture: texture_2d<f32>;

// ============ 顶点着色器输出结构 ============
struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) uv: vec2<f32>,
}

// ============ 顶点着色器 ============
@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> VertexOutput {
    // 生成两个三角形覆盖全屏
    var pos = array<vec2<f32>, 6>(
        vec2<f32>(-1.0, -1.0),  // 左下
        vec2<f32>(1.0, -1.0),   // 右下
        vec2<f32>(-1.0, 1.0),   // 左上
        vec2<f32>(-1.0, 1.0),   // 左上
        vec2<f32>(1.0, -1.0),   // 右下
        vec2<f32>(1.0, 1.0),    // 右上
    );

    var uv = array<vec2<f32>, 6>(
        vec2<f32>(0.0, 1.0),
        vec2<f32>(1.0, 1.0),
        vec2<f32>(0.0, 0.0),
        vec2<f32>(0.0, 0.0),
        vec2<f32>(1.0, 1.0),
        vec2<f32>(1.0, 0.0),
    );

    var output:  VertexOutput;
    output.position = vec4<f32>(pos[vertex_index], 0.0, 1.0);
    output.uv = uv[vertex_index];
    return output;
}

// ============ 片段着色器 ============
@fragment
fn fs_main(input: VertexOutput) -> @location(0) vec4<f32> {
    // 从源纹理采样并输出
    let color = textureSample(source_texture, texture_sampler, input.uv);
    return color;
}