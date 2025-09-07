// Helper function to check if a key has a given prefix
pub fn has_prefix(key_parts: List(String), prefix_parts: List(String)) -> Bool {
  case prefix_parts, key_parts {
    [], _ -> True
    [prefix_head, ..prefix_tail], [key_head, ..key_tail]
      if prefix_head == key_head
    -> has_prefix(key_tail, prefix_tail)
    _, _ -> False
  }
}
