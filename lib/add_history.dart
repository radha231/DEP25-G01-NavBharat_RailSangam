import 'package:firebase_database/firebase_database.dart';
import 'dart:convert';

void addStationsToFirebase() {
  final DatabaseReference database = FirebaseDatabase.instance.ref();

  Map<String, Map<String, String>> stations = {
    "Kalka": {
      "historical_significance": "Kalka is a town in the Panchkula district of Haryana, India, serving as a gateway to the Himalayan hill station of Shimla via the Kalka-Shimla Railway.",
      "url": "https://en.wikipedia.org/wiki/Kalka_railway_station",
      "image_url": "https://dynamic-media-cdn.tripadvisor.com/media/photo-o/16/20/0a/2d/photo0jpg.jpg?w=900&h=500&s=1",
    },
    "Chandigarh": {
      "historical_significance": "Chandigarh is a city, district and union territory in India that serves as the capital of the states of Punjab and Haryana. As a union territory, the city is ruled directly by the Union Government of India and is not under the governance of either Punjab or Haryana.",
      "url": "https://en.wikipedia.org/wiki/Chandigarh_railway_station",
      "image_url": "https://dynamic-media-cdn.tripadvisor.com/media/photo-o/09/4c/43/64/the-rock-garden-of-chandigarh.jpg?w=900&h=500&s=1",
    },
    "Ambala Cantt": {
      "historical_significance": "Ambala Cantonment is a cantonment town in Ambala district in the state of Haryana, India. It is an important railway junction and a major army base.",
      "url": "https://en.wikipedia.org/wiki/Ambala_Cantonment_Junction_railway_station",
      "image_url": "https://i.ytimg.com/vi/cTyiV302vgk/maxresdefault.jpg",
    },
    "Ambala": {
      "historical_significance": "Ambala is a city and a municipal corporation in Ambala district in the state of Haryana, India, located on the border with the state of Punjab. ",
      "url": "https://en.wikipedia.org/wiki/Ambala_City_railway_station",
      "image_url": "https://haryanatourism.gov.in/wp-content/uploads/2024/07/bhawani_pic1.jpg",
    },
    "Kurukshetra": {
      "historical_significance": "Kurukshetra is a city in the state of Haryana, India. It is also known as Dharmakshetra (Sanskrit: धर्मक्षेत्र, 'the Field of Dharma' or 'the Field of Righteousness'). It is believed that the Mahabharata war was fought here.",
      "url": "https://en.wikipedia.org/wiki/Kurukshetra_Junction_railway_station",
      "image_url": "https://dynamic-media-cdn.tripadvisor.com/media/photo-o/17/c6/54/4c/brahma-sarovar.jpg?w=1200&h=-1&s=1",
    },
    "Panipat": {
      "historical_significance": "Panipat is a city in Haryana, India. It is known for the three historic battles fought near the city. It is an ancient city with a rich historical past. The city is located 90 km north of Delhi.",
      "url": "https://en.wikipedia.org/wiki/Panipat_Junction_railway_station",
      "image_url": "https://images.wanderon.in/blogs/new/2024/08/explore-panipat-battlefield-memorial.jpg",
    },
    "Delhi": {
      "historical_significance": "Delhi, officially known as the National Capital Territory (NCT) of Delhi, is a city and a union territory of India containing New Delhi, the capital of India. ",
      "url": "https://en.wikipedia.org/wiki/Delhi_Junction_railway_station",
      "image_url": "https://s7ap1.scene7.com/is/image/incredibleindia/red-fort-delhi-attr-hero?qlt=82&ts=1727352293417",
    },
    "Mathura": {
      "historical_significance": "Mathura is a city and the administrative headquarters of Mathura district in the Indian state of Uttar Pradesh. It is located approximately 50 kilometres (31 mi) north of Agra, and 145 kilometres (90 mi) south-east of Delhi; about 11 kilometres (6.8 mi) from the town of Vrindavan, and 22 kilometres (14 mi) from Govardhan. It is an ancient city with a rich historical past, and is venerated as the birthplace of the Hindu deity Krishna.",
      "url": "https://en.wikipedia.org/wiki/Mathura_Junction_railway_station",
      "image_url": "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcT0QrAeFtD5MG_RMSukNFLvqHS2xG9o1B4KmA&s",
    },
    "Kota": {
      "historical_significance": "Kota is a city located in the southeast of the Indian state of Rajasthan. It is located about 240 kilometres (149 mi) south of the state capital, Jaipur.",
      "url": "https://en.wikipedia.org/wiki/Kota_Junction_railway_station",
      "image_url": "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQVads1LHS-C3DtBQE4XhjGinIG9Y_6awizbQ&s",
    },
    "Ratlam": {
      "historical_significance": "Ratlam is a city located in the Malwa region of Madhya Pradesh, India. It serves as the administrative headquarters of Ratlam district.",
      "url": "https://en.wikipedia.org/wiki/Ratlam_Junction_railway_station",
      "image_url": "https://dynamic-media-cdn.tripadvisor.com/media/photo-o/07/43/15/26/cactus-garden-sailana.jpg?w=1200&h=1200&s=1",
    },
    "Vadodara": {
      "historical_significance": "Vadodara, also known as Baroda, is a major city in the Indian state of Gujarat. It serves as the administrative headquarters of the Vadodara district and is situated on the banks of the Vishwamitri River.",
      "url": "https://en.wikipedia.org/wiki/Vadodara_Junction_railway_station",
      "image_url": "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRhI-4oyNxL-MCZeRaUqoXwEapBtBBL4vzxSQ&s",
    },
    "Mumbai Central": {
      "historical_significance": "Mumbai is the capital city of the Indian state of Maharashtra. Mumbai is the financial, commercial, and entertainment capital of India. It is also one of the world's top ten centers of commerce in terms of global financial flow.",
      "url": "https://en.wikipedia.org/wiki/Mumbai_Central_railway_station",
      "image_url": "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcT6DJQjAC0GyD8gFODbeYpErL6fIjHERJ99Lw&s",
    },
    "Saharanpur": {
      "historical_significance": "Saharanpur is a city and a municipal corporation in Uttar Pradesh, India. Saharanpur is also the administrative headquarters of Saharanpur district.",
      "url": "https://en.wikipedia.org/wiki/Saharanpur_Junction_railway_station",
      "image_url": "https://content.jdmagicbox.com/comp/def_content_category/botanical-gardens/ba1f53c977-botanical-gardens-5-hij93.jpg",
    },
    "Moradabad": {
      "historical_significance": "Moradabad is a city, commissionary and a municipal corporation in Moradabad district of Uttar Pradesh, India. Moradabad is situated on the banks of the Ramganga river, is about 167 km (104 mi) from the national capital New Delhi.",
      "url": "https://en.wikipedia.org/wiki/Moradabad_Junction_railway_station",
      "image_url": "https://dynamic-media-cdn.tripadvisor.com/media/photo-o/0e/27/7f/0e/photo0jpg.jpg?w=1200&h=1200&s=1",
    },
    "Agra Cantt": {
      "historical_significance": "Agra is a city on the banks of the Yamuna river in the Indian state of Uttar Pradesh, about 210 kilometres (130 mi) south of the national capital New Delhi and 335km west of Prayagraj. Agra is a major tourist destination because of its many Mughal-era buildings, most notably the Taj Mahal, Agra Fort and Fatehpur Sikri, all of which are UNESCO World Heritage Sites.",
      "url": "https://en.wikipedia.org/wiki/Agra_Cantonment_railway_station",
      "image_url": "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQ1Gm3AX8tRU2u6E5b9M4SFDJUWJD4h7pUa1g&s",
    },
    "Gwalior": {
      "historical_significance": "Gwalior is a major city in the central Indian state of Madhya Pradesh and one of the Counter-magnet cities. Located 343 kilometers (213 mi) south of Delhi, the capital city of India, 120 kilometers (75 mi) from Agra and 414 kilometers (257 mi) from Bhopal, the state capital, Gwalior occupies a strategic location in the Gird region of India.",
      "url": "https://en.wikipedia.org/wiki/Gwalior_Junction_railway_station",
      "image_url": "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQ1Gm3AX8tRU2u6E5b9M4SFDJUWJD4h7pUa1g&s",
    },
    "Jhansi": {
      "historical_significance": "Jhansi is a historic city in the Indian state of Uttar Pradesh. It lies in the region of Bundelkhand on the banks of the Pahuj River, in the extreme south of Uttar Pradesh. Jhansi is the administrative headquarters of Jhansi district and Jhansi division.",
      "url": "https://en.wikipedia.org/wiki/Jhansi_Junction_railway_station",
      "image_url": "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQUNj294hMkEJmnfg0ZcP8JX6kgfiUVhvxb7g&s",
    },
    "Bhopal": {
      "historical_significance": "Bhopal is the capital city of the Indian state of Madhya Pradesh and the administrative headquarters of both Bhopal district and Bhopal division. Bhopal is known as the City of Lakes for its various natural and artificial lakes and is also one of the greenest cities in India.",
      "url": "https://en.wikipedia.org/wiki/Bhopal_Junction_railway_station",
      "image_url": "https://cdn.britannica.com/34/13134-050-B1D24123/Taj-ul-Masjid-Madhya-Pradesh-Bhopal-India-country-mosque.jpg",
    },
    "Itarsi": {
      "historical_significance": "Itarsi is a city and municipality in Madhya Pradesh, India in Narmadapuram district. Itarsi is a key hub for agricultural goods and is the biggest railway junction in Madhya Pradesh.",
      "url": "https://en.wikipedia.org/wiki/Itarsi_Junction_railway_station",
      "image_url": "https://c8.alamy.com/comp/ERYK5X/itarsi-railway-station-at-madhya-pradesh-india-ERYK5X.jpg",
    },
    "Surat": {
      "historical_significance": "Surat, previously known as Suryapur, is a city in the Indian state of Gujarat. It is the eighth most populated city in India and is the second largest city in Gujarat after Ahmedabad.",
      "url": "https://en.wikipedia.org/wiki/Surat_railway_station",
      "image_url": "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTmQuWPIWrcuRQJue9eWcsuunX7mG97OTWtCQ&s",
    },
    "Borivali": {
      "historical_significance": "Borivali is a suburban area located in the north-western part of Mumbai, Maharashtra, India. Borivali is known for its national park, Sanjay Gandhi National Park, and its religious temples.",
      "url": "https://en.wikipedia.org/wiki/Borivali_railway_station",
      "image_url": "https://jugyah-dev-property-photos.s3.ap-south-1.amazonaws.com/Borivali_West_48fbd306c2.webp",
    },
    "Bandra Terminus": {
      "historical_significance": "Bandra is an upscale coastal suburb of the city of Mumbai, India. The name Bandra is possibly an anglicized version of the original name for the area, Vandre.",
      "url": "https://en.wikipedia.org/wiki/Bandra_Terminus",
      "image_url": "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTAf5CByDtrcExIrXRUDw5GlwZepH0eizK3Fw&s",
    },
    "Bareilly": {
      "historical_significance": "Bareilly is a city in Bareilly district in the Indian state of Uttar Pradesh. It is the centre of Bareilly division and the seat of the Bareilly College.",
      "url": "https://en.wikipedia.org/wiki/Bareilly_Junction_railway_station",
      "image_url": "https://content.jdmagicbox.com/comp/bareilly/u5/9999px581.x581.190324032537.r1u5/catalogue/sunni-jama-masjid-richha-bareilly-mosques-1jutxreapk.jpg",
    },
    "Shahjahanpur": {
      "historical_significance": "Shahjahanpur is a city and a municipal corporation in Shahjahanpur district in the Indian state of Uttar Pradesh. Shahjahanpur is known for its thriving sugar industry and is a major trading center for agricultural products.",
      "url": "https://en.wikipedia.org/wiki/Shahjahanpur_railway_station",
      "image_url": "https://im.hunt.in/cg/shahjahanpur/City-Guide/Shahjahanpur.jpg",
    },
    "Lucknow": {
      "historical_significance": "Lucknow is the capital and the largest city of the Indian state of Uttar Pradesh and is also the second largest urban agglomeration in Uttar Pradesh. Lucknow has always been known as a multicultural city that flourished as a North Indian cultural and artistic hub and the seat of the Shia Nawabs in the 18th and 19th centuries.",
      "url": "https://en.wikipedia.org/wiki/Lucknow_Charbagh_railway_station",
      "image_url": "https://static.toiimg.com/photo/103890972.cms",
    },
    "Kanpur": {
      "historical_significance": "Kanpur is a metropolis in the state of Uttar Pradesh in India. Kanpur is also known as the Leather City for its leather and textile industries. It is the most populous city in the state and the second largest city in North India.",
      "url": "https://en.wikipedia.org/wiki/Kanpur_Central_railway_station",
      "image_url": "https://kanpurtourism.in/images/places-to-visit/headers/shri-radhakrishna-temple-jk-temple-kanpur-tourism-entry-fee-timings-holidays-reviews-header.jpg",
    },
    "Etawah": {
      "historical_significance": "Etawah is a city and district headquarters of Etawah district in the Indian state of Uttar Pradesh. Etawah is situated on the confluence of Yamuna and Chambal Rivers.",
      "url": "https://en.wikipedia.org/wiki/Etawah_Junction_railway_station",
      "image_url": "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSG1Cdp_u0-pauOv50VN53Zlyx-_FQRHQZ1Ug&s",
    },
    "Tundla": {
      "historical_significance": "Tundla is a city and a municipal board in Firozabad district in the Indian state of Uttar Pradesh. Tundla is an important railway junction on the Delhi–Howrah main line.",
      "url": "https://en.wikipedia.org/wiki/Tundla_Junction_railway_station",
      "image_url": "https://images.bhaskarassets.com/web2images/521/2022/02/24/2336cd75-2f4a-4f25-a1ce-60ca1945a0071645686254716_1645702692.jpg",
    },
    "Prayagraj": {
      "historical_significance": "Prayagraj, also known as Allahabad, is a city in the Indian state of Uttar Pradesh. It lies at the confluence of the Ganges, Yamuna, and the mythical Saraswati rivers. It is one of the largest cities of Uttar Pradesh.",
      "url": "https://en.wikipedia.org/wiki/Prayagraj_railway_station",
      "image_url": "https://www.abhibus.com/blog/wp-content/uploads/2023/07/Triveni-Sangam.jpg",
    },
    "Nagpur": {
      "historical_significance": "Nagpur is the third largest city and the winter capital of the state of Maharashtra, India. It is the 13th largest city in India by population and according to an Oxford Economics report, Nagpur is projected to be the fifth fastest growing city in the world from 2019 to 2035 with an average growth of 8.41%.",
      "url": "https://en.wikipedia.org/wiki/Nagpur_railway_station",
      "image_url": "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQH8KygcKD69oXcFa15rb_kExvMOwYSCMyF_Q&s",
    },
    "Vijayawada": {
      "historical_significance": "Vijayawada is a city in the Indian state of Andhra Pradesh. It is located on the banks of the Krishna River, surrounded by the hills of the Eastern Ghats.",
      "url": "https://en.wikipedia.org/wiki/Vijayawada_Junction_railway_station",
      "image_url": "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQsC92BgYEb9xsM-6h6FYrJYDVqSpHrRPp-yw&s",
    },
    "Ernakulam": {
      "historical_significance": "Ernakulam is the central portion of the city of Kochi in Kerala, India and has lent its name to the Ernakulam district. Many major establishments, including the Kerala High Court, the Cochin Stock Exchange, the headquarters of the Southern Naval Command, the Kerala State Financial Enterprises, and the Cochin Port Trust are situated here.",
      "url": "https://en.wikipedia.org/wiki/Ernakulam_Junction_railway_station",
      "image_url": "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQHkj1ehhJvbgId6OaHQCHPzSBUXvlRlyucqw&s",
    },
    "Kochuveli": {
      "historical_significance": "Kochuveli is a suburb of Thiruvananthapuram city in Kerala, India, located about 8 km from the city center. It is known for the Kochuveli railway station and the Vikram Sarabhai Space Centre (VSSC).",
      "url": "https://en.wikipedia.org/wiki/Kochuveli_railway_station",
      "image_url": "https://dynamic-media-cdn.tripadvisor.com/media/photo-o/06/0b/83/99/kovalam-beach.jpg?w=1200&h=-1&s=1",
    },
    "Ludhiana": {
      "historical_significance": "Ludhiana is a large city in the Indian state of Punjab. The city stands on the old bank of the Sutlej River, that flows 13 kilometers (8.1 mi) south of its present course. It is an industrial center of northern India.",
      "url": "https://en.wikipedia.org/wiki/Ludhiana_Junction_railway_station",
      "image_url": "https://education.icar.gov.in/univ_info_file/241-00025788_PAU_APP.jpg",
    },
    "Jalandhar": {
      "historical_significance": "Jalandhar is a city in the Indian state of Punjab. It is the headquarters of Jalandhar district. Jalandhar is an ancient city with a rich history and is known for its sports goods industry.",
      "url": "https://en.wikipedia.org/wiki/Jalandhar_City_railway_station",
      "image_url": "https://shreedevitalabmandir.org/extra-images/slide-2.jpg",
    },
    "Amritsar": {
      "historical_significance": "Amritsar, historically also known as Ramdaspur and colloquially as Ambarsar, is the second-largest city in the Indian state of Punjab, located near the border with Pakistan. It is the spiritual and cultural center of the Sikh religion and is home to the Harmandir Sahib, also known as the Golden Temple.",
      "url": "https://en.wikipedia.org/wiki/Amritsar_Junction_railway_station",
      "image_url": "https://upload.wikimedia.org/wikipedia/commons/thumb/9/94/The_Golden_Temple_of_Amrithsar_7.jpg/1200px-The_Golden_Temple_of_Amrithsar_7.jpg",
    },
    "Gorakhpur": {
      "historical_significance": "Gorakhpur is a city in the Indian state of Uttar Pradesh, along the banks of the Rapti river. It is the administrative headquarters of Gorakhpur district and Gorakhpur division.",
      "url": "https://en.wikipedia.org/wiki/Gorakhpur_railway_station",
      "image_url": "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQbt6_YaYEWR-igkYq0ydj8ekV00tAPas4wvA&s",
    },
    "Guwahati": {
      "historical_significance": "Guwahati is a city in the Indian state of Assam and also the largest metropolis in northeastern India. Dispur, the capital of Assam, is located within the city.",
      "url": "https://en.wikipedia.org/wiki/Guwahati_railway_station",
      "image_url": "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcR5Fg1QBbqcz0atW8SYwSfPPhGFa-LFDQnf5g&s",
    },
    "Dibrugarh": {
      "historical_significance": "Dibrugarh is a city in Assam, India, serving as the headquarters of the Dibrugarh district. It is the largest city in upper Assam.",
      "url": "https://en.wikipedia.org/wiki/Dibrugarh_railway_station",
      "image_url": "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSB3VVZ5s9Z1svTg_6oxaW8CWLecFMn61Au_Q&s",
    },
    "Jaipur": {
      "historical_significance": "Jaipur is the capital and largest city of the Indian state of Rajasthan. It is also known as the Pink City, due to the dominant color scheme of its buildings.",
      "url": "https://en.wikipedia.org/wiki/Jaipur_railway_station",
      "image_url": "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRuDD8CIjBDuVukV24jBDSDnW6-DUu3qrzpeQ&s",
    },
    "Gurgaon": {
      "historical_significance": "Gurgaon, officially known as Gurugram, is a city located in the northern Indian state of Haryana. It is situated near Delhi's Indira Gandhi International Airport, making it a significant commercial and transportation hub.",
      "url": "https://en.wikipedia.org/wiki/Gurgaon_railway_station",
      "image_url": "https://www.holidify.com/images/cmsuploads/compressed/attr_1838_20190221142113jpg",
    },
    "Rewari": {
      "historical_significance": "Rewari is a city and a municipal council in Rewari district in the Indian state of Haryana. It is located in southern Haryana, 82 km southwest of Delhi.",
      "url": "https://en.wikipedia.org/wiki/Rewari_railway_station",
      "image_url": "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTn_pzle9OrDm6xh3dXj2N4VVtPePpPFwfc7w&s",
    },
    "Nangal Dam": {
      "historical_significance": "Nangal is a town in Rupnagar district in Punjab, India. It is located near the border with Himachal Pradesh and is known for the Bhakra-Nangal Dam, one of the largest dams in India.",
      "url": "https://en.wikipedia.org/wiki/Nangal_Dam_railway_station",
      "image_url": "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTAqv-FkkXIgC9b0WpfmdzVyyN_sjHgp6LRzA&s",
    },
    "Ropar": {
      "historical_significance": "Ropar, officially Rupnagar, is a city and a municipal council in Rupnagar district in the Indian state of Punjab. It is located on the banks of the Sutlej River and is known for its historical and archaeological sites.",
      "url": "https://en.wikipedia.org/wiki/Ropar_railway_station",
      "image_url": "https://upload.wikimedia.org/wikipedia/commons/7/77/Water_Lake_in_Northern_India.jpg",
    },
    "Morinda": {
      "historical_significance": "Morinda, also known as Sri Chamkaur Sahib, is a town and a municipal council in Rupnagar district in the Indian state of Punjab. It is known for the Gurdwara Qatalgarh Sahib, which commemorates the martyrdom of the elder sons of Guru Gobind Singh.",
      "url": "https://en.wikipedia.org/wiki/Morinda_railway_station",
      "image_url": "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQLFbYJled1c1Nr29pHPsClPJU8po7WaE8mSg&s",
    },
    "Una": {
      "historical_significance": "Una is a city and a municipal council in Una district in the Indian state of Himachal Pradesh. It is the headquarters of Una district.",
      "url": "https://en.wikipedia.org/wiki/Una_railway_station",
      "image_url": "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSVT4N9IjS7a3KKDqXRBtv-btJTq98KxGIIXA&s",
    },
    "Amb Andaura": {
      "historical_significance": "Amb Andaura is a town in Una district of Himachal Pradesh, India. It is located near the Punjab border.",
      "url": "https://en.wikipedia.org/wiki/Amb_Andaura_railway_station",
      "image_url": "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTvv_eRKKjdfwvIJ2Gb9TUyZLb-wpladPNDhg&s",
    },
  };

  String getPrettyJSONString(Map<String, dynamic> jsonObject) {
    var encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(jsonObject);
  }

  stations.forEach((key, value) {
    String formattedJson = getPrettyJSONString(value);
    database.child('stations').child(key).set(json.decode(formattedJson));
  });
}
