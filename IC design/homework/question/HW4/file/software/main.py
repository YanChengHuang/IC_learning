from PIL import Image
import numpy as np
import torchvision.transforms as transforms
from scipy.signal import convolve2d
import skimage.measure
import math
def decimal_to_binary_fixed(decimal, bits_integer=4, bits_fractional=4):
    integer_part = int(decimal)
    fractional_part = decimal - integer_part

    binary_integer = bin(abs(integer_part))[2:].zfill(bits_integer)
    binary_fractional = ""

    for _ in range(bits_fractional):
        fractional_part *= 2
        bit = int(fractional_part)
        binary_fractional += str(bit)
        fractional_part -= bit

    return '0'*(9-len(binary_integer)) + binary_integer +  binary_fractional

def savedat(data, filename):
    height, width = data.shape
    with open(filename, 'w') as file:
        for h in range(height):
            for w in range(width):
                file.write(str(decimal_to_binary_fixed(data[h][w])) + ' //data {}: {}'.format(64*h+w, data[h][w])+'\n')
    return

def main():

    # Load the image
    image_path = './image.jpg'  
    image = Image.open(image_path)

    # Convert the image to grayscale
    gray_image = image.convert('L')

    # Resize the image to 64x64 pixels
    resize_transform = transforms.Resize((64, 64),antialias=True)
    resized_image = resize_transform(gray_image)
    
   
    resized_image_array = np.array(resized_image)
    print("resize image:{}".format(resized_image_array))

    # save resized image here
    savedat(resized_image_array, 'img.dat')

    padded_resize_image = np.pad(resized_image_array,(2,),'edge')
    print("padded resize image:{}".format(padded_resize_image))
    
    # Given Kernel and bias
    kernel = np.array([[-0.0625, 0, -0.125, 0 , -0.0625],[0,0,0,0,0], [-0.25, 0, 1, 0, -0.25],[0,0,0,0,0], [-0.0625, 0, -0.125, 0, -0.0625]])
    bias = -0.75
   
    # print(-0.0625*40+-0.125*40+-49*0.0625-40*0.25+40-49*0.25-35*0.0625-35*0.125-42*0.0625)
    
    # Convolve
    dilated_conv_result = convolve2d(padded_resize_image, kernel, mode='valid') + bias
    print("convolved image:{}".format(dilated_conv_result))
    # relu function
    height, width = dilated_conv_result.shape
    for h in range(height):
        for w in range(width):
            if(dilated_conv_result[h][w]<0):  dilated_conv_result[h][w] = 0
    print("relu output: {}".format(dilated_conv_result))

    # save layer0 output here
    savedat(dilated_conv_result, 'layer0_golden.dat')

    maxpooling = skimage.measure.block_reduce(dilated_conv_result, (2,2), np.max)
    print("output: {}".format(maxpooling))
    height, width = maxpooling.shape
    final_output = np.zeros((height, width))

    for h in range(height):
        for w in range(width):
            final_output[h][w] = math.ceil(maxpooling[h][w])
    print("finals:{}".format(final_output))
    savedat(final_output, 'layer1_golden.dat')
    # save layer1 output here



if __name__ == '__main__':
    main()
    