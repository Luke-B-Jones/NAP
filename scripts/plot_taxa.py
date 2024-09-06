import pandas as pd
import matplotlib.pyplot as plt
import argparse
import os

# Set up argument parser
parser = argparse.ArgumentParser(description="Plot stacked barplots for genus and species level abundance.")
parser.add_argument('input_file', type=str, help='Path to input TSV file')
parser.add_argument('output_file', type=str, help='Path to save the output plot (PNG or JPEG format)')

# Parse arguments
args = parser.parse_args()

# Load the TSV file based on the provided input file path
df = pd.read_csv(args.input_file, sep='\t')

# Function to extract genus and species from the full taxonomy path
def extract_genus_species(taxonomy):
    parts = taxonomy.split(';')
    
    # If the taxonomy path has more than two levels, assume it's a full path
    if len(parts) >= 2:
        genus = parts[-2].strip()  # Second to last is genus
        species = parts[-1].strip()  # Last is species
    else:
        genus = taxonomy.strip()
        species = ''
    
    return genus, species

# Apply the function to extract genus and species
df[['genus', 'species']] = df['taxonomy'].apply(lambda x: pd.Series(extract_genus_species(x)))

# Calculate relative abundance (percentage)
df['abundance'] = df['abundance'] / df['abundance'].sum() * 100

# Aggregate by genus and species for plotting
genus_df = df.groupby('genus')['abundance'].sum().reset_index()
species_df = df.groupby('species')['abundance'].sum().reset_index()

# Sort data to ensure consistent color assignment in the plot
genus_df = genus_df.sort_values(by='abundance', ascending=False)
species_df = species_df.sort_values(by='abundance', ascending=False)

# Plotting
fig, axes = plt.subplots(ncols=2, figsize=(14, 8))

# Genus level stacked bar chart
axes[0].bar([0], genus_df['abundance'].values, color=plt.cm.Paired.colors[:len(genus_df)], label=genus_df['genus'])
axes[0].set_title('Genus Level Abundance')
axes[0].set_xticks([0])
axes[0].set_xticklabels(['Total Sample'])
axes[0].set_ylabel('Relative Abundance (%)')

# Species level stacked bar chart
axes[1].bar([0], species_df['abundance'].values, color=plt.cm.Paired.colors[:len(species_df)], label=species_df['species'])
axes[1].set_title('Species Level Abundance')
axes[1].set_xticks([0])
axes[1].set_xticklabels(['Total Sample'])
axes[1].set_ylabel('Relative Abundance (%)')

# Add legends
axes[0].legend(genus_df['genus'], bbox_to_anchor=(1.05, 1), loc='upper left', title='Genus')
axes[1].legend(species_df['species'], bbox_to_anchor=(1.05, 1), loc='upper left', title='Species')

# Adjust layout and save the plot
plt.tight_layout()
plt.savefig(args.output_file, dpi=300)

# Open the image after saving
os.system(f'xdg-open {args.output_file}')
