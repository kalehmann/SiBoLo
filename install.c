//    Copyright (c) 2017 by Karsten Lehmann <ka.lehmann@yahoo.com>

/*
 *	This program is free software: you can redistribute it and/or modify
 *	it under the terms of the GNU General Public License as published by
 *	the Free Software Foundation, either version 3 of the License, or
 *	(at your option) any later version.
 *
 *	This program is distributed in the hope that it will be useful,
 *	but WITHOUT ANY WARRANTY; without even the implied warranty of
 *	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *	GNU General Public License for more details.
 *
 *	You should have received a copy of the GNU General Public License
 *	along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/*
 * 	This programm writes the simple bootloader SiBoLo on a floppy image,
 * 	configures it to load a certain file and keeps the bios parameter block
 * 	of the floppy image.
 */

#include<stdio.h>
#include<stdlib.h>
#include<inttypes.h>
#include<string.h>

#define BOOTLOADER_SIZE 512
// Force the compiler to leave no space between the elements of the struct.
#pragma pack(1)
struct BPB {
	char OEMLabel[8];
	uint16_t SectorSize;
	uint8_t SectorsPerCluster;
	uint16_t ReservedForBoot;
	uint8_t NumberOfFats;
	uint16_t RootDirEntrys;
	uint16_t LogicalSectors;
	char MediumByte;
	uint16_t SectorsPerFat;
	uint16_t SectorsPerTrack;
	uint16_t NumberOfHeads;
	uint32_t HiddenSectors;
	uint32_t LargeSectors;
	uint8_t DriveNumber;
	char Reserved;
	char Signature;
	char VolumeID[4];
	char VolumeLabel[11];
	char FileSystem[8];
};

int read_bootloader(char* fname, char* bootloader) {
	// Open the file given in fname and read BOOTLOADER_SIZE bytes into
	// bootloader.
	// Returns -1 on error, else 0
	FILE* bootloader_file = fopen(fname, "r");
	if (bootloader_file == NULL) {
		return -1;
	}
	fread(bootloader, BOOTLOADER_SIZE, 1, bootloader_file);
	fclose(bootloader_file);
	return 0;
}

void print_usage(char* name) {
	printf("Usage : %s [bootloader.file] [floppy.image] [stage2.bin]\n \
		The name of stage2 should not exceed 12 characters and the\n \
		filename extension should be at max 3 characters long.\n",
		name);
}

int read_4x_bpb(char* fname, struct BPB* bpb) {
	// Open the file given in fname and copy it into the struct bpb.
	// It also checks, if the version of the bpb is 40 or 41.
	// Returns -1 on error, else 0
	FILE* floppy = fopen(fname, "r");
	if (floppy == NULL) {
		return -1;
	}
	fseek(floppy, 3, SEEK_SET);
	fread((char*) bpb, sizeof(struct BPB), 1, floppy);
	fclose(floppy);
	
	if (bpb->Signature != 40 && bpb->Signature != 41) {
		return -1;
	}
	return 0;
}

void format_f_name(char* fname, char* out) {
	// Formats the name given in fname to a length of 11 characters, not dot
	// between file name and file extension name and padds the remaining
	// space with spaces.
	char* f_ending = strstr(fname, ".");
	for (int i=0; i<11; i++) {
		out[i] = ' ';
	}
	out[12] = 0;
	memcpy(out, fname, f_ending - fname);
	memcpy(out+8, f_ending + 1, strlen(f_ending+1));
}

char* array_in_array(char* haystack, char* needle, ssize_t size) {
	// Return a pointer to the needle in the haystack with the size of the 
	// haystack given in size.
	// Returns NULL if the needle is not in the haystack.
	char* res;
	for(int i=0; i<size; i++) {
		if ((res = strstr(haystack + i, needle)) != NULL) {
			return res;
		}
	}
	return NULL;
}

int write_bootloader(char* fname, char* bootloader) {
	// Opens the file in fname and overwrites the first BOOTLOADER_SIZE
	// bytes with the bootloader.
	FILE* floppy = fopen(fname, "r+");
	if (floppy == NULL) {
		return -1;
	}
	fwrite(bootloader, BOOTLOADER_SIZE, 1, floppy);
	
	fclose(floppy);
	return 0;
}

int main(int argc, char* argv[]) {
	
	struct BPB bpb;
	char ss_name[12];
	
	if (argc != 4) {
		print_usage(argv[0]);
		return EXIT_SUCCESS;
	}
	if (strlen(argv[3]) > 12) {
		printf("Error, the filename of the second stage is to long\n");
		return EXIT_FAILURE;
	}
		
	if (argv[3] + strlen(argv[3]) - strstr(argv[3], ".") > 4) {
		printf("Error, the filename extension of the second stage is\n \
			longer than 3 bytes long.\n");
		return EXIT_FAILURE;
	}
	
	format_f_name(argv[3], ss_name);
	
	char* bootloader = malloc(BOOTLOADER_SIZE);
	if (bootloader == NULL) {
		printf("Error while allocating memory for bootloader :( \n");
		return EXIT_FAILURE;
	}
	
	if (read_bootloader(argv[1], bootloader) == -1) {
		printf("Error while reading bootloader file %s :(\n", argv[1]);
		return EXIT_FAILURE;
	}
	
	if (read_4x_bpb(argv[2], &bpb) == -1) {
		printf("Error while reading bpb from floppy file %s :(\n",
		       argv[2]);
		return EXIT_FAILURE;
	}
	
	char* bootloader_fname = array_in_array(bootloader, "SecondStage",
						BOOTLOADER_SIZE);
	if (bootloader_fname == NULL) {
		printf("Error, could not find file name in bootloader %s :(\n",
		       argv[1]);
		return EXIT_FAILURE;
	}
	memcpy(bootloader_fname, ss_name, 11);
	memcpy(bootloader + 3, (char*) &bpb, sizeof(struct BPB));
	if (write_bootloader(argv[2], bootloader) == -1) {
		printf("Error while writing bootloader to floppy file %s :(\n",
		       argv[2]);
	}	
	free(bootloader);
}
