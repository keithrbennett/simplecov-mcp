# frozen_string_literal: true

module ResultsetMockHelpers
  # Mock File.read to raise an error (for file system errors like EACCES, ENOENT)
  # Defaults to matching .resultset.json files only, allowing other File.read calls to work normally
  def mock_file_read_error(error, path_matcher: end_with('.resultset.json'))
    allow(File).to receive(:read).and_call_original
    allow(File).to receive(:read).with(path_matcher).and_raise(error)
  end

  # Mock JSON.parse to raise an error (for JSON parsing errors)
  # Defaults to matching .resultset.json files only
  def mock_json_parse_error(error, json_content: 'invalid json')
    allow(File).to receive(:read).and_call_original
    allow(File).to receive(:read).with(end_with('.resultset.json')).and_return(json_content)
    allow(JSON).to receive(:parse).with(json_content).and_raise(error)
  end

  # Mock File.read to return JSON data
  # Defaults to matching .resultset.json files only, allowing other File.read calls to work normally
  def mock_resultset_data(data, path_matcher: end_with('.resultset.json'))
    allow(File).to receive(:read).and_call_original
    allow(File).to receive(:read).with(path_matcher).and_return(JSON.generate(data))
  end
end
