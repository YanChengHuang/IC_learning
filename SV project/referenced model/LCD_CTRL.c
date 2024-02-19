#include <svdpi.h>
#include <stdio.h>

int min_max(int x, int y, int sel){
	// if sel==1 => max mode;
	if(x > y){
        if(sel) return x;
		else return y;
    }else{
        if(sel) return y;
		else return x;
    }
}

void image_operator(int* image_idx, svBitVecVal image[64], int cmd){
		int left_up, right_up, left_down, right_down, left_up_idx, right_up_idx, left_down_idx, right_down_idx;
		
		left_up_idx = *image_idx-9;
		right_up_idx= *image_idx-8;
		left_down_idx= *image_idx-1;
		right_down_idx= *image_idx;
		
		left_up = image[left_up_idx];
		right_up= image[right_up_idx];
		left_down= image[left_down_idx];
		right_down= image[right_down_idx];
		switch(cmd){
			// write: dont need to write, bacause have done it already
			case 0: 
				break;
			// shift up
			case 1:{
				if(*image_idx <= 15) break;
				else{
					(*image_idx) -= 8;
					break;
				}
			}
			// shift down
			case 2:{
				if(*image_idx >= 56) break;
				else{
					(*image_idx) += 8;
					break;
				} 
			}
			// shift left
			case 3:{
				if((*image_idx % 8) == 1) break;
				else{
					(*image_idx) -= 1;
					break;
				}
			}
			// shift right
			case 4:{
				if((*image_idx % 8) == 7) break;
				else{
					(*image_idx) += 1;
					break;
				}
			}
			// max
			case 5:{
				int sel=1;
				int left_max = min_max(left_up, left_down, sel);
				int right_max = min_max(right_up, right_down, sel);
				int max = min_max(left_max,right_max,sel);
				image[left_up_idx] = image[right_up_idx] = image[left_down_idx] = image[right_down_idx] = max;
				break;
			}
				
			// min
			case 6:{
				int sel=0;
				int left_min = min_max(left_up, left_down, sel);
				int right_min = min_max(right_up, right_down, sel);
				int min = min_max(left_min,right_min,sel);
				image[left_up_idx] = image[right_up_idx] = image[left_down_idx] = image[right_down_idx] = min;
				break;
			}
				
			// average
			case 7:{
				int average = (left_up + left_down + right_up + right_down) >> 2;
				image[left_up_idx] = image[right_up_idx] = image[left_down_idx] = image[right_down_idx] = average;
				break;
			}
			// counterclock rotation
			case 8:{
				image[left_up_idx] = right_up;
				image[right_up_idx] = right_down;
				image[left_down_idx] = left_up;
				image[right_down_idx] = left_down;
				break;
			}	
			// clockwise retation
			case 9:{
				image[left_up_idx] = left_down;
				image[right_up_idx] = left_up;
				image[left_down_idx] = right_down;
				image[right_down_idx] = right_up;
				break;
			}		
			// mirror x
			case 10:{
				image[left_up_idx] = left_down;
				image[right_up_idx] = right_down;
				image[left_down_idx] = left_up;
				image[right_down_idx] = right_up;
				break;
			}	
			// mirror y
			case 11:{
				image[left_up_idx] = right_up;
				image[right_up_idx] = left_up;
				image[left_down_idx] = right_down;
				image[right_down_idx] = left_down;
				break;
			}		
			default:{
				printf("Error input! Out of range");
				break;
			}
		}
}

void LCD_CTRL_C(const svBitVecVal generated_image[64], const svOpenArrayHandle cmd_array, svBitVecVal returned_image[64]){
	
	// Assign whole generated image to returned_image first;

	int image_idx = 0;
	int image_size = 64;
	for(image_idx;image_idx<image_size;image_idx++) returned_image[image_idx] = generated_image[image_idx];

	// Iterate all cmd_array
	int cmd_idx, cmd_size, *cmd;
	cmd = (int *)svGetArrayPtr(cmd_array);
	cmd_size = svSize(cmd_array, 1);
	image_idx = 36;
	for (cmd_idx=0;cmd_idx<cmd_size;cmd_idx++){
		image_operator(&image_idx, returned_image, cmd[cmd_idx]);
	}
}

