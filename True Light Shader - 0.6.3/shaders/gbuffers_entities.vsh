#version 330 compatibility

#include "/lib/common.glsl"

out vec2 texcoord;
out vec2 lmcoord;
out vec4 glcolor;
out vec3 normal;
out vec3 viewPos;
out vec4 shadowClipPos;

void main() {
    vec4 viewPos4 = gl_ModelViewMatrix * gl_Vertex;
    gl_Position = gl_ProjectionMatrix * viewPos4;
    viewPos = viewPos4.xyz;

    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    glcolor = gl_Color;

    normal = gl_NormalMatrix * gl_Normal;

    vec3 feetPlayerPos = (gbufferModelViewInverse * viewPos4).xyz;
    vec3 worldNormal = mat3(gbufferModelViewInverse) * normalize(normal);
    shadowClipPos = shadowProjection * shadowModelView * vec4(feetPlayerPos + worldNormal * 0.05, 1.0);
}
