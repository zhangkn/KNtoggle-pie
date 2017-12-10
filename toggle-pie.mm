////////////////////////////////////////////////////////////////////////////////
// HEADERS                                                                    //
////////////////////////////////////////////////////////////////////////////////
#include <stdint.h>
#include <mach-o/loader.h>

////////////////////////////////////////////////////////////////////////////////
// ENUMS                                                                      //
////////////////////////////////////////////////////////////////////////////////
typedef enum ARCH_ENUM
{
    ARCH_32_BIT,
    ARCH_64_BIT
} ARCH;

////////////////////////////////////////////////////////////////////////////////
// HELPER FUNCTIONS                                                           //
////////////////////////////////////////////////////////////////////////////////

// For pretty printing of bytes.
void hexify(unsigned char *data, uint32_t size)
{
    while(size--)
    {
        printf("%02x", *data++);
    }
}

// For pretty printing of header flags.
void print_header_flags(mach_header *header_32, mach_header_64 *header_64)
{
    if (header_32)
    {
        hexify((unsigned char *)&header_32->flags, sizeof(header_32->flags));
        printf("\n");
    }
    else if (header_64)
    {
        hexify((unsigned char *)&header_64->flags, sizeof(header_64->flags));
        printf("\n");
    }
}

// Helper for getting file size.
//     Note: Assumes the file is open for reading and doesn't close it.
size_t get_file_size(FILE *input_file)
{
    // Declarations.
    size_t file_size;

    // Seek to the end of the file and count the
    // number of bytes from the start.
    fseek(input_file, 0, SEEK_END);
    file_size = ftell(input_file);
    rewind(input_file);

    // Return.
    return file_size;
}

// Helper for reading files into a buffer. Returns 0 if successful, 1 otherwise.
//     Note: Does NOT close the passed file, assumes you have read privileges.
int read_file_into_buffer(FILE *input_file, char file_buffer[])
{
    // Declarations.
    size_t file_size;

    // Get the file size.
    file_size = get_file_size(input_file);

    // Copy the file into the buffer.
    if (fread(file_buffer, sizeof(char), file_size, input_file) !=
        file_size)
    {
        return 1;
    }

    // Successful.
    return 0;
}

// Helper for backing up files. Return the writeable file handler for the file
// that is to be edited. Also loads the contents of the file into the buffer.
FILE * backup_file(char *file_name, char* &file_buffer)
{
    // Declarations.
    FILE *original_file;
    FILE *backup_file;
    char backup_suffix[5] = ".bak";
    char backup_file_name[strlen(file_name) + strlen(backup_suffix) + 1];
    size_t file_size;

    // Construct new backup filename by appending the suffix.
    strlcpy(backup_file_name, file_name, sizeof(backup_file_name));
    strlcat(backup_file_name, backup_suffix, sizeof(backup_file_name));

    // Open the file for editing.
    original_file = fopen(file_name, "r+");
    if (!original_file)
    {
        printf("[ERROR] Unable to open the binary file.\n");
        return NULL;
    }

    // Get file size.
    file_size = get_file_size(original_file);

    // Open the backup file.
    backup_file = fopen(backup_file_name, "w");
    if (!backup_file)
    {
        printf("[ERROR] Could not open the backup file.\n");
        return NULL;
    }

    // Allocate space for the buffer.
    file_buffer = (char *)calloc(1, file_size + 1);

    // Copy the file into the temporary copy buffer.
    if (read_file_into_buffer(original_file, file_buffer))
    {
        printf("[ERROR] Could not read the binary file into memory.\n");
        return NULL;
    }

    // Write the copy buffer to the backup file.
    if (fwrite(file_buffer, sizeof(char), file_size, backup_file) != file_size)
    {
        // Couldn't write the correct number of bytes.
        printf("[ERROR] Could not copy file.\n");
        return NULL;
    }

    // Close the backup file.
    fclose(backup_file);

    // Return the file handler for the original file.
    //     Note: this handler is open for editing.
    return original_file;
}

// Helper for toggling the PIE bit.
void toggle_pie_bit_helper(uint32_t &flags)
{
    // Toggles the right bit.
    flags ^= 1 << 21;
}

// Helper for flipping the PIE bit in the given binary file buffer
// for the selected architecture. The binary file is expected to be loaded into
// the passed buffer.
// Returns:
//     0 - Successfully flipped the PIE bit.
//     1 - Couldn't find the magic number.
//     2 - Some other error.
int flip_pie(FILE *binary_file, char binary_file_buffer[], ARCH arch)
{
    // Declarations.
    struct mach_header header_32;
    struct mach_header_64 header_64;
    int header_size;
    uint32_t magic;
    unsigned char leading_byte;
    char *leading_byte_location;
    size_t file_size;

    // Check the buffer.
    if (!binary_file_buffer)
    {
        printf("[ERROR] Buffer is not loaded with the binary file data.\n");
        return 2;
    }

    // Set the magic number and leading byte for the selected architecture.
    magic = (arch == ARCH_32_BIT) ? MH_MAGIC : MH_MAGIC_64;
    leading_byte = magic & 0xff;

    // Set the header size.
    header_size =
        (arch == ARCH_32_BIT) ? sizeof(mach_header) : sizeof(mach_header_64);

    // Get file size.
    file_size = get_file_size(binary_file);

    // Look for the magic number in the buffer.
    leading_byte_location = binary_file_buffer;
    do
    {
        // Determine the amount of space not looked at in the file yet.
        unsigned long remaining_space =
            binary_file_buffer +
            file_size -
            leading_byte_location;

        // If there isn't enough space for the header struct to fit in the
        // file, break.
        if (remaining_space < header_size)
        {
            break;
        }

        // Look for the beginning of the magic number.
        leading_byte_location =
            (char *)memchr(leading_byte_location, leading_byte, remaining_space);

        // Break if couldn't find the magic number.
        if (!leading_byte_location)
        {
            break;
        }

        // Found leading byte. See if the four
        // bytes match the magic number.
        if (memcmp(leading_byte_location, &magic, 4) == 0)
        {
            // Found the location of the magic number!
            printf("Original Mach-O header: ");
            hexify((unsigned char *)leading_byte_location, header_size);
            printf("\n");

            // Seek to the header location in the binary file.
            fseek(
                binary_file,
                leading_byte_location - binary_file_buffer,
                SEEK_SET
            );

            // Read in the header structure from the file.
            if (arch == ARCH_32_BIT)
            {
                if(fread(&header_32, header_size, 1, binary_file) == 0)
                {
                    printf("[ERROR] Could not read header from binary file.\n");
                    return 2;
                }

                // Print out the original flags.
                printf("Original Mach-O header flags: ");
                print_header_flags(&header_32, NULL);

                // Flip the PIE bit.
                printf("Flipping the PIE...\n");
                toggle_pie_bit_helper(header_32.flags);

                // Print out the new flags.
                printf("New Mach-O header flags: ");
                print_header_flags(&header_32, NULL);
            }
            else
            {
                if(fread(&header_64, header_size, 1, binary_file) == 0)
                {
                    printf("[ERROR] Could not read header from binary file.\n");
                    return 2;
                }

                // Print out the original flags.
                printf("Original Mach-O header flags: ");
                print_header_flags(NULL, &header_64);

                // Flip the PIE bit.
                printf("Flipping the PIE...\n");
                toggle_pie_bit_helper(header_64.flags);

                // Print out the new flags.
                printf("New Mach-O header flags: ");
                print_header_flags(NULL, &header_64);
            }

            // Seek back to the header location in the binary file.
            fseek(
                binary_file,
                leading_byte_location - binary_file_buffer,
                SEEK_SET
            );

            // Write the new header to the binary file.
            if (arch == ARCH_32_BIT)
            {
                if(fwrite(&header_32, sizeof(char), sizeof(mach_header), binary_file) == 0)
                {
                    printf("[ERROR] Could not write the new header to the binary file.\n");
                    return 2;
                }
            }
            else
            {
                if(fwrite(&header_64, sizeof(char), sizeof(mach_header_64), binary_file) == 0)
                {
                    printf("[ERROR] Could not write the new header to the binary file.\n");
                    return 2;
                }
            }

            // Success!
            return 0;
        }
        else
        {
            // Didn't find the leading byte. Increment by one.
            leading_byte_location += 1;
        }
    } while (true);

    // Couldn't find the magic number and associated header.
    return 1;
}

// Helper for performing the PIE flip step.
void perform_pie_flip
(
    FILE *binary_file,
    char binary_file_buffer[],
    ARCH arch,
    int step_number
)
{
    // Declarations.
    int pie_flip_result;
    char bit_string_32[7] = "32-bit";
    char bit_string_64[7] = "64-bit";
    char *bit_string;

    // Set the bit string.
    bit_string = (arch == ARCH_32_BIT) ? bit_string_32 : bit_string_64;

    // Show step beginning.
    printf("[STEP %d] Flip the %s PIE...\n", step_number, bit_string);

    // Perform the flip!
    pie_flip_result = flip_pie(binary_file, binary_file_buffer, arch);

    // Parse the flip result.
    if (pie_flip_result == 0)
    {
        printf(
            "[STEP %d] Successfully flipped the %s PIE.\n",
            step_number,
            bit_string
        );
    }
    else if (pie_flip_result == 1)
    {
        printf(
            "[STEP %d] Could not find the %s Mach-O header.\n",
            step_number,
            bit_string
        );
        printf("          This is expected if the binary isn't compiled for\n");
        printf("          a %s architecture.\n", bit_string);
    }
    else
    {
        printf(
            "[STEP %d] Bad things happened trying to flip the PIE.\n",
            step_number
        );
    }
}

////////////////////////////////////////////////////////////////////////////////
// MAIN                                                                       //
////////////////////////////////////////////////////////////////////////////////
int main(int argc, char **argv, char **envp)
{
    // Declarations.
    FILE *binary_file;
    char *binary_file_buffer;

    // Check if the correct number of arguments were given.
    if (argc <= 1)
    {
        printf("Usage: %s <path_to_binary>\n", argv[0]);
        return EXIT_FAILURE;
    }

    // Now backup the file before doing anything.
    printf("[STEP 1] Backing up the binary file...\n");
    binary_file = backup_file(argv[1], binary_file_buffer);
    if (!binary_file)
    {
        printf("[ERROR] Exiting because could not back up the binary file.\n");
        return EXIT_FAILURE;
    }
    printf("[STEP 1] Binary file successfully backed up to %s.bak\n", argv[1]);
    printf("\n");

    // Flip the 32-bit PIE.
    perform_pie_flip(binary_file, binary_file_buffer, ARCH_32_BIT, 2);
    printf("\n");

    // Flip the 64-bit PIE.
    perform_pie_flip(binary_file, binary_file_buffer, ARCH_64_BIT, 3);

    // Close the binary file.
    fclose(binary_file);

    // Shouldn't get here! Failure.
    return EXIT_SUCCESS;
}