# Offline Knowledge Bases

There are several offline repositories that are made freely available
using a `.zim` file. Depending on the resource, they can be quite large.
EmComm Tools Community includes an offline reader called "Kiwix" for 
searching and reading these resources offline.

1. Visit: http://download.kiwix.org/zim/wikipedia/

2. To save space when building your image, consider some of the smaller
   Wikipedia topic areas, such as:

   * `wikipedia_en_computer_nopic_YYYY-MM.zim`
   * `wikipedia_en_history_nopic_YYYY-MM.zim`
   * `wikipedia_en_mathematics_nopic_YYYY-MM.zim`
   * `wikipedia_en_medicine_nopic_2024-04.zim`
   * `wikipedia_en_simple_all_nopic_YYYY-MM.zim`

   The full Wikipedia export without images is 56 GB. This file is better
   stored separately and excluded from the ETC ISO build image.

3. Copy these `.zim` file to `/etc/skel/wikipedia` during the image build.

4. Other high-value offline exports to look into are available at:

   * https://download.kiwix.org/zim/ifixit/

5. Run `kiwix` after a fresh installation. Your .zim files will
   be available in your home directory in the `wikipedia` folder.

