/* Copyright (c) 2018 by Karsten Lehmann <mail@kalehmann.de>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 *
 * This program writes the simple bootloader SiBoLo on a floppy image,
 * configures it to load a certain file and keeps the bios parameter block
 * of the floppy image.
 */

#include<ctype.h>
#include<stdio.h>
#include<stdlib.h>
#include<string.h>

#define BOOTLOADER_SIZE 512

/* Prints the usage of this program and exits immediately. */
static void print_usage(char *name)
{
	printf("Usage : %s [bootloader.file] [floppy.image] [FILE.BIN]\n"
	       "The filename of the file the bootloader loads should not exceed 12 characters,\n"
	       "the base name should be at maximum 8 characters long and\n"
	       "the length of file extension should not exceed 3 characters.\n",
	       name);
	exit(1);
}

/*
 * Validates if a filename is suitable for the usage with a FAT12 file system.
 * Check that the name is all uppercase, the base name does not exceed 8 bytes
 * and the file extension does not exceed 3 bytes.
 *
 * Exits on an invalid filename.
 */
static void validate_filename(const char *filename)
{
	for (int i=0 ; i<strlen(filename); i++) {
		if (filename[i] != '.' && !isupper(filename[i])) {
			printf("Error, the name of the file the bootloader loads should only contain uppercase characters.\n");
			exit(1);
		}
	}
	if (strchr(filename, '.') != NULL) {
		if (strlen(filename) > 12) {
			printf("Error, the name of the file the bootloader loads is too long\n");
			exit(1);
		}
		size_t dot_pos = strchr(filename, '.') - filename;
		if (dot_pos > 8) {
			printf("Error, the base name of the file the bootloader loads is too long\n");
			exit(1);
		}
		if (strlen(filename) - dot_pos > 4) {
			printf("Error, the extension of the file the bootloader loads is too long\n");
			exit(1);
		}


	} else {
		if (strlen(filename) > 8) {
			printf("Error, the base name of the file the bootloader loads is to long\n");
			exit(1);
		}
	}
}

/*
 * Reads the path to the bootloader file, the path to the floppy file and the
 * name of the file the bootloader should load from the arguments.
 *
 * Prints the usage of the program and exits immediately if the wrong number of
 * arguments is provided or the filename has a wrong format.
 */
static void handle_args(int argc, char* argv[], char** bootloader_file,
		char** floppy_file, char** filename)
{

	if (argc != 4) {
		print_usage(argv[0]);
	}

	validate_filename(argv[3]);

	*bootloader_file = argv[1];
	*floppy_file = argv[2];
	*filename = argv[3];
}

/*
 * Reads the bootloader from a binary file.
 */
static char *read_bootloader(char *bootloader_path)
{
	char *bootloader = malloc(BOOTLOADER_SIZE);
	if (bootloader == NULL) {
		printf("Error while allocating memory for the bootloader\n");
		exit(1);
	}
	FILE *bootloader_file = fopen(bootloader_path, "r");
	if (bootloader_file == NULL) {
		printf("Error opening %s\n", bootloader_path);
		exit(1);
	}

	fseek(bootloader_file, 0 , SEEK_END);
	if (ftell(bootloader_file) != BOOTLOADER_SIZE) {
		printf("Error, expected the bootloader to have a size of %d bytes.\n",
			BOOTLOADER_SIZE);
		exit(1);
	}
	fseek(bootloader_file, 0, SEEK_SET);
	
	fread(bootloader, BOOTLOADER_SIZE, 1, bootloader_file);
	fclose(bootloader_file);
	return bootloader;

}


/*
 * Converts a filename to the 8.3 format. 8 bytes padded with spaces for the
 * short filename and 3 bytes padded with spaces for the short file extension.
 */
static char *format_name_83(const char *filename)
{
	char *name_83 = malloc(11);

	if (name_83 == NULL) {
		printf("Error while allocating memory for the 8.3 name\n");
		exit(1);
	}

	for (int i=0; i<11; i++) {
		name_83[i] = ' ';
	}
	char *short_file_name = name_83, *short_file_ending = &name_83[8];
	char *file_ending;
	if ((file_ending = strchr(filename, '.')) != NULL) {
		file_ending += sizeof(char);
		size_t basename_length = file_ending - filename - 1;
		size_t ending_length = strlen(file_ending);
		memcpy(short_file_name, filename, basename_length);
		memcpy(short_file_ending, file_ending, ending_length);
	} else {
		memcpy(short_file_name, filename, strlen(filename));
	}

	return name_83;
}

/*
 * Determines the position of the filename to load inside the bootloader.
 */
static char *filename_position(char *bootloader)
{
	char *placeholder = "PLACEHOLDER";
	int j = 0;

	for (int i = 0; i < BOOTLOADER_SIZE; i++) {
		if (bootloader[i] == placeholder[j]) {
			j++;
		} else {
			j = 0;
		}
		if (j == 11) {
			return &bootloader[i-10];
		}
	}

	printf("Could not locate the position of the filename in the bootloader\n");
	exit(1);
}

/*
 * Sets the name of the file to load in the bootloader.
 */
static void bootloader_set_filename(char* bootloader, const char* filename)
{
	char *name_83 = format_name_83(filename);
	char *boot_name = filename_position(bootloader);

	memcpy(boot_name, name_83, 11);

	free(name_83);
}

/*
 * Copies the OEM name and the Extended Bios Parameter Block from the floppy to
 * the bootloader (bytes 3 - 0x3d) and verifies the extended boot signature.
 */
static void bootloader_set_bpb(char *bootloader, const char *floppy_name)
{
	char *bpb = &bootloader[3];
	FILE* floppy = fopen(floppy_name, "r");
	if (floppy == NULL) {
		printf("Error while reading the file %s\n", floppy_name);
		exit(1);
	}
	fseek(floppy, 3, SEEK_SET);
	fread(bpb, 0x3a, 1, floppy);
	fclose(floppy);

	/*
	 * Check the extended boot signature to verify if this bios parameter
	 * block will be understood by the bootloader. The offset of the
	 * extended boot signature on the floppy is 0x26 bytes. This program
	 * copies the bios parameter block from byte 3 on the floppy, therefore
	 * the offset in the variable bpb is 0x26 - 3 = 0x23.
	 */
	if (bpb[0x23] != 40 && bpb[0x23] != 41) {
		printf("Error, found no valid BPB on %s\n", floppy_name);
		exit(1);
	}
}
/*
 * Writes the bootloader to a floppy image.
 */
static void bootloader_write_to_floppy(const char *bootloader, const char *floppy_name)
{
	FILE* floppy = fopen(floppy_name, "r+");
	if (floppy == NULL)
	{
		printf("Error while opening %s for writing\n", floppy_name);
		exit(1);
	}
	fwrite(bootloader, BOOTLOADER_SIZE, 1, floppy);

	fclose(floppy);
}

int main(int argc, char* argv[])
{
	char *bootloader_file, *floppy_file, *file_name;
	handle_args(argc, argv, &bootloader_file, &floppy_file, &file_name);

	char* bootloader = read_bootloader(bootloader_file);
	bootloader_set_filename(bootloader, file_name);
	bootloader_set_bpb(bootloader, floppy_file);
	bootloader_write_to_floppy(bootloader, floppy_file);
	free(bootloader);
}
