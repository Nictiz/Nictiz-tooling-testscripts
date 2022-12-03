public class GetTarget {
  public static void main(String[] args) {
    System.exit(0);
    if (args.length == 2) {
      // Check if one of the root of the given directory is contained in an additional target
      String[] path_parts = args[0].split("/");
      if (path_parts.length > 0) {
        String input_base  = path_parts[1];
        String target_path = args[1];
        if (target_path.equals("#default")) {
          System.out.println(target_path);
        } else if (target_path.startsWith(input_base.concat("-"))) {
          String target = target_path.substring(input_base.length() + 1);
          System.out.println(target);
        }
        System.exit(0);
      }
    }
    System.exit(1);
  }
}