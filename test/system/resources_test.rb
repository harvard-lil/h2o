require "application_system_test_case"

class ResourceSystemTest < ApplicationSystemTestCase
  before do
    @resource = content_nodes(:resource_with_full_case)
    sign_in users(:user_with_full_case)
    visit annotate_resource_path @resource.casebook, @resource
  end

  scenario 'annotations disappear when their selected text is deleted', js: true do
    text = 'Brett A. Ringle, of Shank, Irwin, Conant & Williamson'
    assert_content text
    assert_selector :css, 'a[href="https://opencasebook.org/"]'

    delete_top_paragraphs
    refresh_page
    refute_selector :css, 'a[href="https://opencasebook.org/"]'

    delete_full_case
    refresh_page
    assert_no_content text
    refute_selector :css, 'a[href="https://opencasebook.org/"]'
  end

  scenario 'highlight annotation stays in the same selected text when paragraph numbers change', js: true do
    sel = '.highlight .selected-text'
    text = 'cash-out merger of Trans Union into the defendant'

    find(sel).assert_text text
    delete_top_paragraphs
    refresh_page
    find(sel).assert_text text
  end

  scenario 'replacement annotation stays in the right place when chars near it are deleted', js: true do
    assert_content ", Marmon Group, Inc., a Delaware corporation, GL Corporation, a"
    assert_no_content "Delaware corporation, and New T. Co., a D"
    assert_content "elaware corporation, Defendants Below, Appellees."

    delete_inline_chars
    refresh_page

    assert_content ", Marmon Group, Inc., a Delaware corporation, GL Corporation, a"
    assert_no_content "Delaware corporation, and New T. Co., a D"
    assert_content "elaware corporation, Defendants Below, Appellees."
  end

  scenario 'note annotation stays in the right place when chars near it are added', js: true do
    sel = '.note .selected-text'
    find(sel).assert_text "m Prickett (argued) and James P. Dall"

    add_inline_chars
    refresh_page
    find(sel).assert_text "m Prickett (argued) and James P. Dall"
  end

  def refresh_page
    visit annotate_resource_path @resource.casebook, @resource
  end

  def delete_top_paragraphs
    # deleted "<center>488 A.2d 858 (1985)</center>\r\n\r\n<center>\r\n<h2>Alden SMITH and John W. Gosselin, Plaintiffs Below, Appellants,<br />\r\nv.<br />\r\nJerome W. VAN GORKOM, Bruce S. Chelberg, William B. Johnson, Joseph B. Lanterman, Graham J. Morgan, Thomas P. O&#39;Boyle, W. Allen Wallis, Sidney H. Bonser, William D. Browder, Trans Union Corporation, a Delaware corporation, Marmon Group, Inc., a Delaware corporation, GL Corporation, a Delaware corporation, and New T. Co., a Delaware corporation, Defendants Below, Appellees.</h2>\r\n</center>\r\n\r\n<center>\r\n<p>Supreme Court of Delaware.<br />\r\nSubmitted: June 11, 1984.<br />\r\nDecided: January 29, 1985.<br />\r\nOpinion on Denial of Reargument: March 14, 1985.</p>\r\n</center>\r\n\r\n<p>William Prickett (argued) and James P. Dalle Pazze, of Prickett, Jones, Elliott, Kristol &amp; Schnee, Wilmington, and Ivan Irwin, Jr. and Brett A. Ringle, of Shank, Irwin, Conant &amp; Williamson, Dallas, Tex., of counsel, for plaintiffs below, appellants.</p>\r\n\r\n<p>Robert K. Payson (argued) and Peter M. Sieglaff of Potter, Anderson &amp; Corroon,</p>\r\n\r\n<p>Before HERRMANN, C.J., and McNEILLY, HORSEY, MOORE and CHRISTIE, JJ., constituting the Court en banc.</p>\r\n\r\n<h2>"
    @resource.resource.update(content: 
      "<h2>[863] HORSEY, Justice (for the majority):</h2>\r\n\r\n<p>This
        appeal from the Court of Chancery involves a class action brought by shareholders
        of the defendant Trans Union Corporation (&quot;Trans Union&quot; or &quot;the
        Company&quot;), originally seeking rescission of a cash-out merger of Trans Union
        into the defendant New T Company (&quot;New T&quot;), a wholly-owned subsidiary
        of the defendant, Marmon Group, Inc. (&quot;Marmon&quot;). Alternate relief in
        the form of damages is sought against the defendant members of the Board of Directors
        of Trans Union, [864] New T, and Jay A. Pritzker and Robert A. Pritzker, owners
        of Marmon.<sup><a href=\"#[1]\" name=\"r[1]\">[1]</a></sup></p>\r\n\r\n<p>----------</p>\r\n\r\n<p><a
        href=\"#r[1]\" name=\"[1]\">[1]</a> The plaintiff, Alden Smith, originally sought
        to enjoin the merger; but, following extensive discovery, the Trial Court denied
        the plaintiff&#39;s motion for preliminary injunction by unreported letter opinion
        dated February 3, 1981. On February 10, 1981, the proposed merger was approved
        by Trans Union&#39;s stockholders at a special meeting and the merger became effective
        on that date. Thereafter, John W. Gosselin was permitted to intervene as an additional
        plaintiff; and Smith and Gosselin were certified as representing a class consisting
        of all persons, other than defendants, who held shares of Trans Union common stock
        on all relevant dates. At the time of the merger, Smith owned 54,000 shares of
        Trans Union stock, Gosselin owned 23,600 shares, and members of Gosselin&#39;s
        family owned 20,000 shares.</p>\r\n")
  end

  def delete_inline_chars
    # deleted "<br />\r\nv.<br />\r\nJerome W. VAN GORKOM, Bruce S. Chelberg, William B. Johnson, Joseph B. Lanterman, Graham J. Morgan, Thomas P. O&#39;Boyle,"
    @resource.resource.update(content: "<center>488 A.2d 858 (1985)</center>\r\n\r\n<center>\r\n<h2>Alden SMITH
    and John W. Gosselin, Plaintiffs Below, Appellants, W. Allen Wallis, Sidney H. Bonser, William D.
    Browder, Trans Union Corporation, a Delaware corporation, Marmon Group, Inc.,
    a Delaware corporation, GL Corporation, a Delaware corporation, and New T. Co.,
    a Delaware corporation, Defendants Below, Appellees.</h2>\r\n</center>\r\n\r\n<center>\r\n<p>Supreme
    Court of Delaware.<br />\r\nSubmitted: June 11, 1984.<br />\r\nDecided: January
    29, 1985.<br />\r\nOpinion on Denial of Reargument: March 14, 1985.</p>\r\n</center>\r\n\r\n<p>William
    Prickett (argued) and James P. Dalle Pazze, of Prickett, Jones, Elliott, Kristol
    &amp; Schnee, Wilmington, and Ivan Irwin, Jr. and Brett A. Ringle, of Shank, Irwin,
    Conant &amp; Williamson, Dallas, Tex., of counsel, for plaintiffs below, appellants.</p>\r\n\r\n<p>Robert
    K. Payson (argued) and Peter M. Sieglaff of Potter, Anderson &amp; Corroon,</p>\r\n\r\n<p>Before
    HERRMANN, C.J., and McNEILLY, HORSEY, MOORE and CHRISTIE, JJ., constituting the
    Court en banc.</p>\r\n\r\n<h2>[863] HORSEY, Justice (for the majority):</h2>\r\n\r\n<p>This
    appeal from the Court of Chancery involves a class action brought by shareholders
    of the defendant Trans Union Corporation (&quot;Trans Union&quot; or &quot;the
    Company&quot;), originally seeking rescission of a cash-out merger of Trans Union
    into the defendant New T Company (&quot;New T&quot;), a wholly-owned subsidiary
    of the defendant, Marmon Group, Inc. (&quot;Marmon&quot;). Alternate relief in
    the form of damages is sought against the defendant members of the Board of Directors
    of Trans Union, [864] New T, and Jay A. Pritzker and Robert A. Pritzker, owners
    of Marmon.<sup><a href=\"#[1]\" name=\"r[1]\">[1]</a></sup></p>\r\n\r\n<p>----------</p>\r\n\r\n<p><a
    href=\"#r[1]\" name=\"[1]\">[1]</a> The plaintiff, Alden Smith, originally sought
    to enjoin the merger; but, following extensive discovery, the Trial Court denied
    the plaintiff&#39;s motion for preliminary injunction by unreported letter opinion
    dated February 3, 1981. On February 10, 1981, the proposed merger was approved
    by Trans Union&#39;s stockholders at a special meeting and the merger became effective
    on that date. Thereafter, John W. Gosselin was permitted to intervene as an additional
    plaintiff; and Smith and Gosselin were certified as representing a class consisting
    of all persons, other than defendants, who held shares of Trans Union common stock
    on all relevant dates. At the time of the merger, Smith owned 54,000 shares of
    Trans Union stock, Gosselin owned 23,600 shares, and members of Gosselin&#39;s
    family owned 20,000 shares.</p>\r\n")
  end

  def add_inline_chars
    # added "adding new content "
    "<center>488 A.2d 858 (1985)</center>\r\n\r\n<center>\r\n<h2>Alden SMITH
    and John W. Gosselin, Plaintiffs Below, Appellants,<br />\r\nv.<br />\r\nJerome
    W. VAN GORKOM, Bruce S. Chelberg, William B. Johnson, Joseph B. Lanterman, Graham
    J. Morgan, Thomas P. O&#39;Boyle, W. Allen Wallis, Sidney H. Bonser, William D.
    Browder, Trans Union Corporation, a Delaware corporation, Marmon Group, Inc.,
    a Delaware corporation, GL Corporation, a Delaware corporation, and New T. Co.,
    a Delaware corporation, Defendants Below, Appellees.</h2>\r\n</center>\r\n\r\n<center>\r\n<p>Supreme
    Court of Delaware.<br />\r\nSubmitted: June 11, 1984.<br />\r\nDecided: January
    29, 1985.<br />\r\nOpinion on Denial of Reargument: March 14, 1985.</p>\r\n</center>\r\n\r\n<p>added inline chars adding new content William
    Prickett (argued) and James P. Dalle Pazze, of Prickett, Jones, Elliott, Kristol
    &amp; Schnee, Wilmington, and Ivan Irwin, Jr. and Brett A. Ringle, of Shank, Irwin,
    Conant &amp; Williamson, Dallas, Tex., of counsel, for plaintiffs below, appellants.</p>\r\n\r\n<p>Robert
    K. Payson (argued) and Peter M. Sieglaff of Potter, Anderson &amp; Corroon,</p>\r\n\r\n<p>Before
    HERRMANN, C.J., and McNEILLY, HORSEY, MOORE and CHRISTIE, JJ., constituting the
    Court en banc.</p>\r\n\r\n<h2>[863] HORSEY, Justice (for the majority):</h2>\r\n\r\n<p>This
    appeal from the Court of Chancery involves a class action brought by shareholders
    of the defendant Trans Union Corporation (&quot;Trans Union&quot; or &quot;the
    Company&quot;), originally seeking rescission of a cash-out merger of Trans Union
    into the defendant New T Company (&quot;New T&quot;), a wholly-owned subsidiary
    of the defendant, Marmon Group, Inc. (&quot;Marmon&quot;). Alternate relief in
    the form of damages is sought against the defendant members of the Board of Directors
    of Trans Union, [864] New T, and Jay A. Pritzker and Robert A. Pritzker, owners
    of Marmon.<sup><a href=\"#[1]\" name=\"r[1]\">[1]</a></sup></p>\r\n\r\n<p>----------</p>\r\n\r\n<p><a
    href=\"#r[1]\" name=\"[1]\">[1]</a> The plaintiff, Alden Smith, originally sought
    to enjoin the merger; but, following extensive discovery, the Trial Court denied
    the plaintiff&#39;s motion for preliminary injunction by unreported letter opinion
    dated February 3, 1981. On February 10, 1981, the proposed merger was approved
    by Trans Union&#39;s stockholders at a special meeting and the merger became effective
    on that date. Thereafter, John W. Gosselin was permitted to intervene as an additional
    plaintiff; and Smith and Gosselin were certified as representing a class consisting
    of all persons, other than defendants, who held shares of Trans Union common stock
    on all relevant dates. At the time of the merger, Smith owned 54,000 shares of
    Trans Union stock, Gosselin owned 23,600 shares, and members of Gosselin&#39;s
    family owned 20,000 shares.</p>\r\n"
  end

  def delete_full_case
    @resource.resource.update(content: "")
  end
end
