uniform mat4 screenMatrix;

attribute vec4 position;
attribute vec2 texCoord0;
attribute vec4 color;

varying vec4 varying_color;
varying vec2 varying_texCoord0;

void main()
{        
	gl_Position = screenMatrix * position;    
    varying_color = vec4(color.b * color.a, color.g * color.a, color.r * color.a, color.a);    
    varying_texCoord0 = texCoord0;
} 
