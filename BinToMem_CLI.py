import sys
import os


def bin_to_mem(infile, outfile):
    binfile = open(infile, 'rb')
    binfile_content = binfile.read(os.path.getsize(infile))
    datafile = open(outfile, 'w')

    for b in  binfile_content:
            array = []
            array.append(b)
            datafile.write(bytearray(array).hex() + '\n')

    binfile.close()
    datafile.close()

def bin_to_mem64(infile, outfile):
    binfile = open(infile, 'rb')
    binfile_content = binfile.read(os.path.getsize(infile))
    datafile = open(outfile, 'w')

    index = 0
    b0 = 0
    b1 = 0
    b2 = 0
    b3 = 0
    b4 = 0
    b5 = 0
    b6 = 0
    b7 = 0

    for b in  binfile_content:
        if index == 0:
            b0 = b
            index = index + 1
        elif index == 1:
            b1 = b
            index = index + 1
        elif index == 2:
            b2 = b
            index = index + 1
        elif index == 3:
            b3 = b
            index = index + 1
        elif index == 4:
            b4 = b
            index = index + 1
        elif index == 5:
            b5 = b
            index = index + 1
        elif index == 6:
            b6 = b
            index = index + 1
        elif index == 7:
            b7 = b
            index = 0
            array = []
            array.append(b7)
            array.append(b6)
            array.append(b5)
            array.append(b4)
            array.append(b3)
            array.append(b2)
            array.append(b1)
            array.append(b0)
            datafile.write(bytearray(array).hex() + '\n')

    binfile.close()
    datafile.close()


if __name__ == '__main__':
    if len(sys.argv) == 4:
        if sys.argv[3] == "64":
            bin_to_mem64(sys.argv[1], sys.argv[2])
        else :
            bin_to_mem(sys.argv[1], sys.argv[2])
    else:
        print('Usage: %s binfile datafile' % sys.argv[0], sys.argv[1], sys.argv[2])
