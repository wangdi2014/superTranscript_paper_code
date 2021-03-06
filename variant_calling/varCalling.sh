# GATK pipeline used to call SNPs on the SuperTranscriptome and genome.

## variable
GenomeFastaPrefix=SuperDuper
GenomeFasta=$GenomeFastaPrefix.fasta
PICARDDIR= #directory to picard tools
GATKDIR= #directory to GATK

## prepare the reference
java -jar $PICARDDIR/picard.jar CreateSequenceDictionary R=$GenomeFasta O=$GenomeFastaPrefix.dict
samtools faidx $GenomeFasta 

java -Xmx6g -jar $PICARDDIR/picard.jar AddOrReplaceReadGroups I=../alignment2/Aligned.sortedByCoord.out.bam O=rg_added_sorted.bam \
SO=coordinate RGLB=GB RGPL=ILLUMINA RGPU=lane RGSM=GB VALIDATION_STRINGENCY=LENIENT

#mark duplicates, and create index
java -Xmx6g -jar $PICARDDIR/picard.jar MarkDuplicates I=rg_added_sorted.bam O=dedupped.bam \
CREATE_INDEX=true VALIDATION_STRINGENCY=SILENT M=output.metrics

#split'n'trim and reassign mapping qualities
java -Xmx6g -jar $GATKDIR/GenomeAnalysisTK.jar -T SplitNCigarReads \
-R $GenomeFasta \
-I dedupped.bam -o split.bam \
-rf ReassignOneMappingQuality -RMQF 255 -RMQT 60 -U ALLOW_N_CIGAR_READS

#variant calling
java -Xmx6g -jar $GATKDIR/GenomeAnalysisTK.jar -T HaplotypeCaller \
-R $GenomeFasta \
-I split.bam -dontUseSoftClippedBases -stand_call_conf 20.0 -o variants.vcf 

#variant filtering
java -Xmx6g -jar $GATKDIR/GenomeAnalysisTK.jar -T VariantFiltration \
-R $GenomeFasta \
-V variants.vcf -window 35 -cluster 3 -filterName FS -filter "FS > 30.0" -filterName QD -filter "QD < 2.0" \
-o filtered_variants.vcf

