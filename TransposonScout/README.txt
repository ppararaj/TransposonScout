TRANSPOSONSCOUT-2.0-linux

1. Overview

  1.1. Purpose
       This document details the steps needed to install and execute 
       TransposonScout for personal use. TransposonScout is a bioinformatics 
       tool for researchers interested in determining possible horizontal gene 
       transfers of an organism based on primary DNA sequence.

  1.2. Scope
       TransposonScout is a Perl-based program that pipes together the functions 
       of RepeatScout (determines repetitive regions of a DNA sequence which correspond 
       to transposable elements) and BLAST search (searches NCBI sequence database for 
       DNA matches in non-query species using RepeatScout transposable elements for 
       queries). BLAST results are parsed, organized by species and displayed in a 
       GUI interface.

  1.3. System Requirements
       • Linux OS
       •1GB or more of RAM
       •1MB of hard disk space for TransposonScout
       •Internet connection

       NOTE: TransposonScout may produce a large number of files during operation and 
             more than 1MB of hard disk space may be required. 

2. Installation

  2.1. Prerequisites
      2.1.1. BioPerl distribution containing RemoteBlast module.
      2.1.2. Tk distribution.

  2.2. Installation
      2.2.1. Download TransposonScout-2.0-linux.tar.gz.
      2.2.2. ‘cd’ to directory containing TransposonScout-2.0-linux.tar.gz.
      2.2.3. ‘tar –zxvf TransposonScout-2.0-linux.tar.gz –C {desired directory}’ 
             in the directory containing the archive file. A directory called 
             “TransposonScout-2.0-linux” will be created in the desired directory. 
      2.2.4. ‘cd’ to “TransposonScout-2.0-linux” directory.
      2.2.5. ‘perl TransposonScout.pl’ to execute TransposonScout.
