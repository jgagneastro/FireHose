# FireHose
A modified version of the Firehose IDL pipeline to reduce data obtained with the Folded-port InfraRed Echellette (FIRE) near-infrared spectrograph described here : http://web.mit.edu/~rsimcoe/www/FIRE/

Please note that I am not the original author of this reduction package, which was created by Robert Simcoe. I have simply made several changes and fixed some glitches to make the pipeline easier to use. Erini Lambridges has helped me in this enterprise.

The latest modifications to this pipeline were made with IDL 8.4. I tried to avoid using IDL 8-specific syntax, however it is possible that I forgot about some of them, which would cause error messages if used with IDL 7. Please contact me if this happens.

Please refer to /FireHose/1-Firehose/Documentation/ECHELLETTE_README.txt to reduce Echelle data with firehose.pro
or to /FireHose/1-Firehose/Documentation/PRISM_README.txt to reduce Prism data with firehose_ld.pro