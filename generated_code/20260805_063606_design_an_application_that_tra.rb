# GitToCrochet - Translates Git commit graph topologies into printable crochet pattern instructions.
# - Rebase histories (commit depth / squashes) determine stitch density and stitch types.
# - Merge conflicts dictate yarn color transitions and standing joining stitches.

class CommitNode
  attr_reader :sha, :parents, :message, :has_conflict, :rebase_depth

  def initialize(sha, parents: [], message: "", has_conflict: false, rebase_depth: 0)
    @sha = sha
    @parents = parents
    @message = message
    @has_conflict = has_conflict
    @rebase_depth = rebase_depth
  end
end

class GitCrochetPatternGenerator
  YARN_PALETTE = [
    "Main Color (MC): Oxford Charcoal",
    "Contrast Color 1 (CC1): Conflict Crimson",
    "Contrast Color 2 (CC2): Rebase Rose Gold",
    "Accent Color (AC): Resolution Emerald"
  ].freeze

  STITCH_DENSITIES = {
    0 => { stitch: "Single Crochet (sc)", density: "Standard (1:1 ratio)", multiplier: 1 },
    1 => { stitch: "Half Double Crochet (hdc)", density: "Medium (1.25x density)", multiplier: 1.25 },
    2 => { stitch: "Double Crochet (dc)", density: "High (1.5x density)", multiplier: 1.5 },
    3 => { stitch: "Bobble Cluster Stitch", density: "Ultra Dense Rebase (2x density)", multiplier: 2.0 }
  }.freeze

  def initialize(history = nil)
    @history = history || default_git_topology
  end

  # Translates the graph into row-by-row crochet instructions
  def generate_pattern
    lines = []
    lines << "=" * 65
    lines << "      GIT COMMIT GRAPH CROCHET PATTERN: 'BRANCH & BIND'"
    lines << "=" * 65
    lines << "\nMATERIALS & SPECIFICATIONS:"
    lines << "  - Yarn: Worsted Weight (#4) in 4 distinct colorways."
    lines << "  - Hook Size: 5.0 mm (US H-8)"
    lines << "  - Gauge: 16 sts x 16 rows = 4\" in single crochet\n"
    lines << "YARN COLOR PALETTE:"
    YARN_PALETTE.each { |col| lines << "  * #{col}" }
    lines << "\nABBREVIATIONS:"
    lines << "  ch: chain | sc: single crochet | hdc: half-double crochet"
    lines << "  dc: double crochet | sl st: slip stitch | st(s): stitch(es)"
    lines << "-" * 65

    current_color_idx = 0
    lines << "\nINSTRUCTIONS:\n"
    lines << "FOUNDATION ROW: Using #{YARN_PALETTE[0].split(':').first}, Ch 25. Turn."

    @history.each_with_index do |commit, index|
      row_num = index + 1
      density_level = [commit.rebase_depth, 3].min
      stitch_spec = STITCH_DENSITIES[density_level]
      stitch_count = (20 * stitch_spec[:multiplier]).to_i

      lines << "\nROW #{row_num} [Commit #{commit.sha[0..6]}]"
      lines << "  Message: \"#{commit.message}\""

      if commit.has_conflict
        current_color_idx = (current_color_idx + 1) % YARN_PALETTE.size
        new_color = YARN_PALETTE[current_color_idx]
        lines << "  *** MERGE CONFLICT AT #{commit.sha[0..6]} ***"
        lines << "  -> Transition Yarn Color: Cut active yarn, join #{new_color} using a Standing St."
      end

      lines << "  Stitch Density: #{stitch_spec[:density]}"
      lines << "  Pattern Row: Ch 1, work #{stitch_count} #{stitch_spec[:stitch]} across row."
      lines << "  Row Finish: Turn piece. (Total: #{stitch_count} sts)"
    end

    lines << "\n" + "=" * 65
    lines << "FINISHING INSTRUCTIONS:"
    lines << "  - Fasten off all remaining active yarn tails."
    lines << "  - Weave in loose ends using a tapestry needle to resolve all merge conflicts."
    lines << "=========================================================="
    lines.join("\n")
  end

  private

  # Default sample DAG simulating merge conflicts and rebase histories
  def default_git_topology
    [
      CommitNode.new("a1b2c3d", message: "Initial commit", rebase_depth: 0),
      CommitNode.new("b2c3d4e", parents: ["a1b2c3d"], message: "Feature branch init", rebase_depth: 0),
      CommitNode.new("c3d4e5f", parents: ["b2c3d4e"], message: "Rebased linear commit #1", rebase_depth: 1),
      CommitNode.new("d4e5f6g", parents: ["c3d4e5f"], message: "Rebased linear commit #2", rebase_depth: 2),
      CommitNode.new("e5f6g7h", parents: ["d4e5f6g"], message: "Merge main with conflicts", has_conflict: true, rebase_depth: 1),
      CommitNode.new("f6g7h8i", parents: ["e5f6g7h"], message: "Squashed hotfix branch", rebase_depth: 3),
      CommitNode.new("g7h8i9j", parents: ["f6g7h8i"], message: "Resolve upstream conflict & release", has_conflict: true, rebase_depth: 0)
    ]
  end
end

# Execute script directly to print pattern
puts GitCrochetPatternGenerator.new.generate_pattern