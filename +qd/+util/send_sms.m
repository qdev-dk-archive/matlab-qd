function send_sms(cellphone, content)
    % Usage: send_sms('+4526642790', 'Triton 6 is so hot.')
    %
    % This service costs 1 cent. Remember to always use a country code on the
    % cell number (the message will be send from Quebec).

    % This is specific to our Twilio account.
    username = 'ACb99d445f1b2f50eff42090445c962654';
    token = '21c0c260ecd5fc9ba60cc8dea0751605';
    number = '+15795000080';

    url = java.net.URL(sprintf('https://api.twilio.com/2010-04-01/Accounts/%s/Messages.json', username));
    conn = url.openConnection();
    conn.setRequestMethod('POST')
    auth = java.lang.String([username ':' token]);
    encoder = sun.misc.BASE64Encoder();
    encoded = char(encoder.encode(auth.getBytes()));
    encoded = strrep(encoded, sprintf('\r'), '');
    encoded = strrep(encoded, sprintf('\n'), '');
    conn.setRequestProperty('Authorization', ['Basic ' encoded]);
    conn.setDoOutput(true);
    output_stream = conn.getOutputStream();
    writer = java.io.BufferedWriter(java.io.OutputStreamWriter(output_stream, 'UTF-8'));
    writer.write(queryencode({ ...
            'To', cellphone, ...
            'From', number, ...
            'Body', content ...
        }));
    writer.flush();
    writer.close();
    output_stream.close();
    conn.connect();
    response = read_from_stream(conn.getContent());
    % TODO, validate response.
end

function q = queryencode(kv)
    first = true;
    q = '';
    for i = [1:2:length(kv)]
        key = kv{i};
        val = kv{i + 1};
        if first
            first = false;
        else
            q = [q '&'];
        end
        q = [q urlencode(key) '=' urlencode(val)];
    end
end

function e = urlencode(s)
    e = char(java.net.URLEncoder.encode(s, 'UTF-8'));
end

function v = read_from_stream(s)
    v = '';
    while true
        x = s.read();
        if x < 0
            break;
        end
        v = [v char(x)];
    end
end