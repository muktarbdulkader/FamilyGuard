const assert = require('node:assert/strict');

const projectId = 'study-app-fbebe';
const documentsUrl =
  `http://127.0.0.1:8080/v1/projects/${projectId}/databases/(default)/documents`;
const authUrl =
  'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key';

function stringValue(value) {
  return { stringValue: value };
}

function arrayValue(values) {
  return { arrayValue: { values: values.map(stringValue) } };
}

async function request(url, options = {}) {
  const response = await fetch(url, options);
  const text = await response.text();
  let body;
  try {
    body = text ? JSON.parse(text) : null;
  } catch {
    body = text;
  }
  return { response, body };
}

async function createAuthenticatedUser(email) {
  const { response, body } = await request(authUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email,
      password: 'test-password-123',
      returnSecureToken: true,
    }),
  });
  assert.equal(response.status, 200, JSON.stringify(body));
  return body;
}

async function writeAsAdmin(path, fields) {
  const { response, body } = await request(`${documentsUrl}/${path}`, {
    method: 'PATCH',
    headers: {
      Authorization: 'Bearer owner',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ fields }),
  });
  assert.ok(response.ok, `Seed ${path} failed: ${JSON.stringify(body)}`);
}

async function authenticatedRequest(path, token, options = {}) {
  return request(`${documentsUrl}/${path}`, {
    ...options,
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
      ...options.headers,
    },
  });
}

async function run() {
  const suffix = `${Date.now()}_${Math.random().toString(16).slice(2)}`;
  const [parent, child, legacyChild, outsider] = await Promise.all([
    createAuthenticatedUser(`parent_${suffix}@example.com`),
    createAuthenticatedUser(`child_${suffix}@example.com`),
    createAuthenticatedUser(`legacy_child_${suffix}@example.com`),
    createAuthenticatedUser(`outsider_${suffix}@example.com`),
  ]);
  const familyId = `chat_rules_${suffix}`;
  const legacyFamilyId = `legacy_chat_rules_${suffix}`;
  const conversationId = `conversation_${suffix}`;
  const familyPath = `families/${familyId}`;
  const legacyFamilyPath = `families/${legacyFamilyId}`;
  const conversationPath = `conversations/${conversationId}`;

  await writeAsAdmin(familyPath, {
    parentIds: arrayValue([parent.localId]),
    childIds: arrayValue([child.localId]),
  });
  await writeAsAdmin(legacyFamilyPath, {
    parentId: stringValue(parent.localId),
    childrenIds: arrayValue([legacyChild.localId]),
  });
  await Promise.all([
    writeAsAdmin(`users/${parent.localId}`, {
      role: stringValue('parent'),
      familyId: stringValue(familyId),
      displayName: stringValue('Test Parent'),
    }),
    writeAsAdmin(`users/${child.localId}`, {
      role: stringValue('child'),
      familyId: stringValue(familyId),
      displayName: stringValue('Test Child'),
    }),
    writeAsAdmin(`users/${legacyChild.localId}`, {
      role: stringValue('child'),
      familyId: stringValue(legacyFamilyId),
      displayName: stringValue('Legacy Test Child'),
    }),
    writeAsAdmin(`users/${outsider.localId}`, {
      role: stringValue('parent'),
      familyId: stringValue('other-family'),
      displayName: stringValue('Outsider'),
    }),
  ]);
  const conversationName =
    `projects/${projectId}/databases/(default)/documents/${conversationPath}`;
  const conversationCreate = await request(`${documentsUrl}:commit`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${parent.idToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      writes: [
        {
          update: {
            name: conversationName,
            fields: {
              familyId: stringValue(familyId),
              parentId: stringValue(parent.localId),
              childId: stringValue(child.localId),
              participantIds: arrayValue([parent.localId, child.localId]),
            },
          },
          updateTransforms: [
            { fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' },
            { fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' },
          ],
        },
      ],
    }),
  });
  assert.equal(
    conversationCreate.response.status,
    200,
    `Linked conversation create denied: ${JSON.stringify(conversationCreate.body)}`,
  );

  const parentRead = await authenticatedRequest(conversationPath, parent.idToken);
  assert.equal(parentRead.response.status, 200, 'Linked parent can read chat');
  const childRead = await authenticatedRequest(conversationPath, child.idToken);
  assert.equal(childRead.response.status, 200, 'Linked child can read chat');
  const childReadsParent = await authenticatedRequest(
    `users/${parent.localId}`,
    child.idToken,
  );
  assert.equal(
    childReadsParent.response.status,
    200,
    'Linked child can read the parent profile',
  );
  const outsiderRead = await authenticatedRequest(
    conversationPath,
    outsider.idToken,
  );
  assert.equal(outsiderRead.response.status, 403, 'Unlinked user is denied');

  const linkedChildren = await request(`${documentsUrl}:runQuery`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${parent.idToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      structuredQuery: {
        from: [{ collectionId: 'users' }],
        where: {
          compositeFilter: {
            op: 'AND',
            filters: [
              {
                fieldFilter: {
                  field: { fieldPath: 'familyId' },
                  op: 'EQUAL',
                  value: stringValue(familyId),
                },
              },
              {
                fieldFilter: {
                  field: { fieldPath: 'role' },
                  op: 'EQUAL',
                  value: stringValue('child'),
                },
              },
            ],
          },
        },
      },
    }),
  });
  assert.equal(
    linkedChildren.response.status,
    200,
    `Parent linked-child query denied: ${JSON.stringify(linkedChildren.body)}`,
  );
  const legacyFamilyRead = await authenticatedRequest(
    legacyFamilyPath,
    parent.idToken,
  );
  assert.equal(
    legacyFamilyRead.response.status,
    200,
    `Legacy family read denied: ${JSON.stringify(legacyFamilyRead.body)}`,
  );
  const legacyFamilies = await request(`${documentsUrl}:runQuery`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${parent.idToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      structuredQuery: {
        from: [{ collectionId: 'families' }],
        where: {
          fieldFilter: {
            field: { fieldPath: 'parentId' },
            op: 'EQUAL',
            value: stringValue(parent.localId),
          },
        },
      },
    }),
  });
  assert.equal(
    legacyFamilies.response.status,
    200,
    `Legacy family query denied: ${JSON.stringify(legacyFamilies.body)}`,
  );
  assert.ok(
    legacyFamilies.body.some((entry) =>
      entry.document?.name.endsWith(`/families/${legacyFamilyId}`),
    ),
    'Parent contact query returns legacy parentId family documents',
  );

  const query = await request(`${documentsUrl}:runQuery`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${parent.idToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      structuredQuery: {
        from: [{ collectionId: 'conversations' }],
        where: {
          compositeFilter: {
            op: 'AND',
            filters: [
              {
                fieldFilter: {
                  field: { fieldPath: 'familyId' },
                  op: 'EQUAL',
                  value: stringValue(familyId),
                },
              },
              {
                fieldFilter: {
                  field: { fieldPath: 'parentId' },
                  op: 'EQUAL',
                  value: stringValue(parent.localId),
                },
              },
              {
                fieldFilter: {
                  field: { fieldPath: 'childId' },
                  op: 'EQUAL',
                  value: stringValue(child.localId),
                },
              },
              {
                fieldFilter: {
                  field: { fieldPath: 'participantIds' },
                  op: 'ARRAY_CONTAINS',
                  value: stringValue(parent.localId),
                },
              },
            ],
          },
        },
      },
    }),
  });
  assert.equal(query.response.status, 200, `Linked inbox query denied: ${JSON.stringify(query.body)}`);
  assert.ok(
    query.body.some((entry) =>
      entry.document?.name.endsWith(`/conversations/${conversationId}`),
    ),
    'Linked inbox query returns the conversation',
  );

  const messageId = `message_${suffix}`;
  const messagePath = `${conversationPath}/messages/${messageId}`;
  const messageName =
    `projects/${projectId}/databases/(default)/documents/${messagePath}`;
  const validMessage = {
    messageId: stringValue(messageId),
    conversationId: stringValue(conversationId),
    familyId: stringValue(familyId),
    senderId: stringValue(parent.localId),
    recipientId: stringValue(child.localId),
    text: stringValue('Hello from the parent'),
    readAt: { nullValue: null },
  };
  const validCreate = await request(`${documentsUrl}:commit`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${parent.idToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      writes: [
        {
          update: { name: messageName, fields: validMessage },
          updateTransforms: [
            { fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' },
          ],
        },
      ],
    }),
  });
  assert.equal(
    validCreate.response.status,
    200,
    `Linked parent message denied: ${JSON.stringify(validCreate.body)}`,
  );

  const receiptWrite = {
    update: { name: messageName, fields: { readAt: { nullValue: null } } },
    updateMask: { fieldPaths: ['readAt'] },
    updateTransforms: [
      { fieldPath: 'readAt', setToServerValue: 'REQUEST_TIME' },
    ],
  };
  const senderReceipt = await request(`${documentsUrl}:commit`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${parent.idToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ writes: [receiptWrite] }),
  });
  assert.equal(
    senderReceipt.response.status,
    403,
    'The sender cannot write a read receipt',
  );
  const recipientReceipt = await request(`${documentsUrl}:commit`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${child.idToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ writes: [receiptWrite] }),
  });
  assert.equal(
    recipientReceipt.response.status,
    200,
    `Linked recipient read receipt denied: ${JSON.stringify(recipientReceipt.body)}`,
  );

  const spoofedCreate = await request(`${documentsUrl}:commit`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${outsider.idToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      writes: [
        {
          update: {
            name:
              `projects/${projectId}/databases/(default)/documents/` +
              `${conversationPath}/messages/spoofed_${suffix}`,
            fields: {
              ...validMessage,
              messageId: stringValue(`spoofed_${suffix}`),
              senderId: stringValue(parent.localId),
            },
          },
          updateTransforms: [
            { fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' },
          ],
        },
      ],
    }),
  });
  assert.equal(
    spoofedCreate.response.status,
    403,
    `Sender spoofing is denied: ${JSON.stringify(spoofedCreate.body)}`,
  );

  const revokedFamily = {
    parentIds: arrayValue([parent.localId]),
    childIds: arrayValue([]),
  };
  await writeAsAdmin(familyPath, revokedFamily);
  const revokedRead = await authenticatedRequest(conversationPath, parent.idToken);
  assert.equal(revokedRead.response.status, 403, 'Revoked participant is denied');

  console.log(
    'Chat Firestore rules passed: linked and legacy contact queries, conversation reads, valid send, recipient-only read receipt, outsider/sender-spoof denial, and revoked-link denial.',
  );
}

run().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
