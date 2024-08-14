import pandas as pd
import sys

def merge_and_reorder_tsv(file_18s, file_16s, output_file, log_file):
    try:
        # Load the 18s data without headers
        data_18s = pd.read_csv(file_18s, sep='\t', header=0)
        
        # Load the 16s data
        data_16s = pd.read_csv(file_16s, sep='\t', header=0)
        
        # Concatenate the data frames
        merged_data = pd.concat([data_16s, data_18s], ignore_index=True)
        
        # Calculate pre-merge total reads
        total_pre_merge = data_16s['abundance'].sum() + data_18s['abundance'].sum()
        
        # Sort the data by 'abundance' in descending order
        merged_data.sort_values('abundance', ascending=False, inplace=True)
        
        # Save the sorted data to the output file
        merged_data.to_csv(output_file, sep='\t', index=False)
        
        # Calculate post-merge total reads
        total_post_merge = merged_data['abundance'].sum()
        
        # Calculate the percentage similarity
        percentage_similarity = 100 * total_post_merge / total_pre_merge
        
        # Log the results
        with open(log_file, 'a') as log:
            log.write(f"Merging and sorting successful. Total pre-merge reads: {total_pre_merge}, Total post-merge reads: {total_post_merge}, Similarity: {percentage_similarity}%\n")
            return True

    except Exception as e:
        # Log any errors that occur
        with open(log_file, 'a') as log:
            log.write(f"Error processing files: {str(e)}\n")
        return False

if __name__ == "__main__":
    if len(sys.argv) != 5:
        print("Usage: python merge_16s_18s.py <file_18s> <file_16s> <output_file> <log_file>")
        sys.exit(1)

    _, file_18s, file_16s, output_file, log_file = sys.argv
    merge_and_reorder_tsv(file_18s, file_16s, output_file, log_file)


