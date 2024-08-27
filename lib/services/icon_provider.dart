class IconProvider{
  static String getAvatar(String num){
    switch(num){
      case "000" :
        return "assets/avatars/avatar.png";
      case "001" :
        return "assets/avatars/avatar_hacker.png";
      case "002" :
        return "assets/avatars/avatar_man_1.png";
      case "003" :
        return "assets/avatars/avatar_man_2.png";
      case "004" :
        return "assets/avatars/avatar_man_3.png";
      case "005" :
        return "assets/avatars/avatar_man_4.png";
      case "006" :
        return "assets/avatars/avatar_woman_1.png";
      case "007" :
        return "assets/avatars/avatar_woman_2.png";
      case "008" :
        return "assets/avatars/avatar_woman_3.png";
      case "009" :
        return "assets/avatars/avatar_woman_4.png";
      default :
        return "assets/avatars/avatar.png";

    }

  }
}