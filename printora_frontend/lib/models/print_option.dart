class PrintOption {
  int copies;
  bool color;
  bool duplex;
  bool allPages;
  String pageRange;

  PrintOption({
    this.copies = 1,
    this.color = false,
    this.duplex = false,
    this.allPages = true,
    this.pageRange = "",
  });
}
